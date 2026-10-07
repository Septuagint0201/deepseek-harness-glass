import AppKit
import WebKit

@main
struct DownloadSmoke {
    static func main() throws {
        _ = NSApplication.shared
        let url = URL(string: CommandLine.arguments[1])!
        let mode = CommandLine.arguments[2]
        let directory = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
        let original = directory.appendingPathComponent("fixture.txt")
        try Data("keep-existing\n".utf8).write(to: original)
        var revealed: URL?
        let controller = GlassWebViewController(url: url, downloadsDirectory: directory) {
            revealed = $0
        }
        let webView = controller.view as! WKWebView
        var clicked = false
        let deadline = Date().addingTimeInterval(20)
        while revealed == nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            if mode == "action", !clicked, webView.url?.path == "/page", !webView.isLoading {
                clicked = true
                webView.evaluateJavaScript("document.getElementById('download').click()")
            }
        }
        precondition(revealed != nil, "Download did not finish / reveal: \(mode)")
        precondition(revealed!.lastPathComponent == "fixture-2.txt", "Filename collision handling failed")
        let saved = try Data(contentsOf: revealed!)
        let existing = try Data(contentsOf: original)
        precondition(saved == Data("glass-download-fixture\n".utf8))
        precondition(existing == Data("keep-existing\n".utf8), "Existing file was overwritten")
        print("PASS download \(mode): bytes, collision suffix, Finder destination")
    }
}
