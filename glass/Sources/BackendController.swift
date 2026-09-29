import AppKit
import Combine
import WebKit

/// Connect to the user's dsh installation. No engine or runtime is bundled.
final class BackendController: NSObject, ObservableObject {
    static let shared = BackendController()
    @Published var url: URL?
    @Published var errorText: String?
    @Published var connectionURL = ""
    private var process: Process?
    private var output = ""
    private var starting = false
    private var generation = 0
    private var restartCount = 0
    private var isQuitting = false
    private(set) var ownsBackend = false

    var homePath: String {
        ProcessInfo.processInfo.environment["DSH_HOME"] ?? NSHomeDirectory() + "/.dsh"
    }
    var logPath: String {
        let directory = NSHomeDirectory() + "/Library/Logs"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        return directory + "/DeepSeek Harness Glass.log"
    }
    private var endpoint: URL {
        Self.localURL(ProcessInfo.processInfo.environment["DSH_WEB_URL"] ?? "")
            ?? Self.localURL(UserDefaults.standard.string(forKey: "dshEndpoint") ?? "")
            ?? URL(string: "http://127.0.0.1:3080/")!
    }

    /// Tokens are accepted only for local HTTP services and never persisted or logged.
    static func localURL(_ value: String) -> URL? {
        guard let u = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              u.scheme == "http", ["127.0.0.1", "localhost", "::1", "[::1]"].contains(u.host ?? ""),
              u.user == nil, u.password == nil, u.path.isEmpty || u.path == "/",
              u.port == nil || (1...65535).contains(u.port!) else { return nil }
        return u
    }
    private func remember(_ target: URL) {
        var clean = URLComponents(url: target, resolvingAgainstBaseURL: false)!
        clean.query = nil
        clean.fragment = nil
        UserDefaults.standard.set(clean.url!.absoluteString, forKey: "dshEndpoint")
    }
    private func appendLog(_ text: String) {
        let safe = text.replacingOccurrences(of: #"([?&]token=)[^\s&]+"#, with: "$1[redacted]", options: .regularExpression)
        if let handle = FileHandle(forWritingAtPath: logPath) {
            handle.seekToEndOfFile()
            handle.write(Data(safe.utf8))
            try? handle.close()
        } else { try? Data(safe.utf8).write(to: URL(fileURLWithPath: logPath)) }
    }
    func connect(_ value: String) {
        guard let target = Self.localURL(value) else {
            errorText = "请输入 dsh web 输出的本地 HTTP 链接（包含 token）。"
            return
        }
        probe(target, mayLaunch: false)
    }
    func start(autoRestart: Bool = false) {
        guard !isQuitting, !starting, process == nil else { return }
        if !autoRestart { restartCount = 0 }
        probe(endpoint, mayLaunch: true)
    }
    private func probe(_ target: URL, mayLaunch: Bool) {
        guard !isQuitting, !starting else { return }
        starting = true
        errorText = nil
        generation += 1
        let attempt = generation
        // WebKit has its own cookie store; Foundation must use those same cookies
        // to recognize a previously authorized external service after an app restart.
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self, self.generation == attempt, !self.isQuitting else { return }
            let configuration = URLSessionConfiguration.ephemeral
            let session = URLSession(configuration: configuration)
            var request = URLRequest(url: target)
            request.timeoutInterval = 3
            let matching = cookies.filter { $0.domain == target.host && !$0.isSecure && ($0.expiresDate ?? .distantFuture) > Date() }
            request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: matching)
            session.dataTask(with: request) { data, response, error in
                session.finishTasksAndInvalidate()
                DispatchQueue.main.async {
                    guard self.generation == attempt, !self.isQuitting else { return }
                    self.starting = false
                    let status = (response as? HTTPURLResponse)?.statusCode
                    let body = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
                    if status == 200 && body.contains("__DSH_BOOT__") {
                        self.remember(target)
                        self.connectionURL = ""
                        self.url = target
                    } else if status == 401 && body.contains("dsh web authentication required") {
                        self.errorText = "检测到已有 dsh 服务。请粘贴该进程输出的完整启动链接，完成首次授权。"
                    } else if mayLaunch, (error as? URLError)?.code == .cannotConnectToHost {
                        self.spawn(target)
                    } else {
                        self.errorText = "无法连接或验证此地址的 dsh 服务。请检查进程和启动链接后重试。"
                    }
                }
            }.resume()
        }
    }
    func restart() {
        generation += 1
        starting = false
        url = nil
        restartCount = 0
        guard let old = process else { start(); return }
        // Wait for termination before probing, so we cannot reattach to a dying child.
        old.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.process === old else { return }
                self.process = nil
                self.ownsBackend = false
                self.start()
            }
        }
        if old.isRunning { old.terminate() }
        else { process = nil; ownsBackend = false; start() }
    }
    func shutdown() {
        isQuitting = true
        generation += 1
        if ownsBackend, let process, process.isRunning { process.terminate() }
    }
    private func spawn(_ target: URL) {
        let child = Process()
        // Finder does not inherit terminal PATH. A login/interactive shell loads the
        // user's fnm/nvm/Homebrew setup; exec keeps dsh as the owned process.
        child.executableURL = URL(fileURLWithPath: "/bin/zsh")
        child.arguments = ["-lic", "export PATH=\"$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin\"; exec \"${DSH_EXECUTABLE:-dsh}\" web --no-open --host \"$GLASS_DSH_HOST\" --port \"$GLASS_DSH_PORT\""]
        var environment = ProcessInfo.processInfo.environment
        environment["DSH_HOME"] = homePath
        environment["GLASS_DSH_HOST"] = target.host == "[::1]" ? "::1" : target.host
        environment["GLASS_DSH_PORT"] = String(target.port ?? 80)
        child.environment = environment
        child.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        child.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        child.standardOutput = pipe
        child.standardError = pipe
        output = ""
        pipe.fileHandleForReading.readabilityHandler = { [weak self, weak child] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            DispatchQueue.main.async {
                guard let self, let child, self.process === child else { return }
                self.handleOutput(String(decoding: data, as: UTF8.self))
            }
        }
        child.terminationHandler = { [weak self] child in
            DispatchQueue.main.async {
                guard let self, self.process === child else { return }
                self.process = nil
                self.ownsBackend = false
                guard !self.isQuitting else { return }
                self.url = nil
                if self.restartCount < 1 {
                    self.restartCount += 1
                    self.start(autoRestart: true)
                } else {
                    self.errorText = "dsh 启动失败或退出（\(child.terminationStatus)）。请确认已安装 dsh 0.1.7-rc.2，且终端能运行 dsh web --no-open。日志：\(self.logPath)"
                }
            }
        }
        do {
            try child.run()
            process = child
            ownsBackend = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self, weak child] in
                guard let self, let child, self.process === child, self.url == nil else { return }
                self.errorText = "等待 dsh 启动超时。请检查日志后重试：\(self.logPath)"
                child.terminationHandler = nil
                child.terminate()
                self.process = nil
                self.ownsBackend = false
            }
        } catch {
            errorText = "无法运行本机 dsh：\(error.localizedDescription)"
        }
    }
    private func handleOutput(_ text: String) {
        output += text
        // Parse complete lines only: pipe chunks can split the authentication token.
        while let newline = output.firstIndex(of: "\n") {
            let line = String(output[..<newline])
            output.removeSubrange(...newline)
            appendLog(line + "\n")
            if url == nil, let marker = line.range(of: "dsh web: ") {
                let value = line[marker.upperBound...].split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
                if let target = Self.localURL(value) { remember(target); url = target }
            }
        }
        if output.count > 65536 { output = String(output.suffix(4096)) }
    }
}
