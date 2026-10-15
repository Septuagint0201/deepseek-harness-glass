import AppKit
import Foundation
import WebKit

@main
struct ConnectionSmoke {
    static func main() {
        _ = NSApplication.shared
        let args = CommandLine.arguments
        let mode = args[1]
        let websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let controller = BackendController(websiteDataStore: websiteDataStore)
        func wait(_ predicate: () -> Bool) {
            let deadline = Date().addingTimeInterval(75)
            while !predicate(), Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            precondition(predicate(), "Timed out: \(controller.errorText ?? "no error")")
        }
        precondition(BackendController.localURL("https://example.com/?token=x") == nil)
        precondition(BackendController.localURL("http://127.0.0.1:3080/?token=abc") != nil)
        if mode == "connect" { controller.connect(args[2]) }
        else { controller.start(); controller.start() } // duplicate starts must be ignored
        if mode == "unauthorized" || mode == "missing" || mode == "occupied" {
            wait { controller.errorText != nil }
            precondition(controller.url == nil)
            precondition(!controller.ownsBackend)
            if mode == "unauthorized" { precondition(controller.errorText!.contains("已有 dsh")) }
        } else {
            wait { controller.url != nil || controller.errorText != nil }
            precondition(controller.url != nil, controller.errorText ?? "no URL")
            precondition(controller.ownsBackend == (mode == "spawn" || mode == "real"))
            if mode == "real" {
                var finished = false
                var valid = false
                let session = URLSession(configuration: .ephemeral)
                session.dataTask(with: controller.url!) { data, response, _ in
                    let ok = (response as? HTTPURLResponse)?.statusCode == 200 &&
                        (data.map { String(decoding: $0, as: UTF8.self).contains("__DSH_BOOT__") } ?? false)
                    DispatchQueue.main.async { valid = ok; finished = true }
                }.resume()
                wait { finished }
                precondition(valid, "Real dsh authentication / frontend failed")
                session.invalidateAndCancel()

                // Exercise the actual modular frontend and Glass injection in WebKit,
                // rather than accepting an HTML boot marker as a rendered application.
                let frontend = GlassWebViewController(url: controller.url!, websiteDataStore: websiteDataStore)
                let webView = frontend.view as! WKWebView
                func evaluate(_ script: String) -> Bool {
                    var result = false
                    var done = false
                    webView.evaluateJavaScript(script) { value, error in
                        result = error == nil && (value as? Bool == true)
                        done = true
                    }
                    wait { done }
                    return result
                }
                wait {
                    evaluate("document.querySelector('#root button') !== null && document.getElementById('dsh-glass-style') !== null")
                }
                for dark in [false, true] {
                    precondition(evaluate("""
                        (() => {
                          document.body.toggleAttribute('data-ds-dark-theme', \(dark));
                          const style = getComputedStyle(document.body);
                          return getComputedStyle(document.getElementById('root')).backgroundColor === 'rgba(0, 0, 0, 0)'
                            && style.getPropertyValue('--dsw-specific-input-major').includes('\(dark ? "28, 29, 34, 0.45" : "211, 217, 228, 0.55")')
                            && style.getPropertyValue('--dsw-alias-bg-layer-2').includes('0.94');
                        })()
                        """), "Real frontend Glass theme failed: dark=\(dark)")
                }
                // WebKit must retain the launch cookie, and Foundation's reconnect
                // probe must be able to use it without keeping the launch token.
                var clean = URLComponents(url: controller.url!, resolvingAgainstBaseURL: false)!
                clean.query = nil
                let cleanURL = clean.url!
                controller.connect(cleanURL.absoluteString)
                wait { controller.url == cleanURL || controller.errorText != nil }
                precondition(controller.errorText == nil && controller.url == cleanURL,
                             "WebKit cookie did not authorize a token-free reconnect")
                print("PASS real WebKit: rendered UI, light/dark Glass CSS, cookie reconnect")
                withExtendedLifetime(frontend) {}
            }
            if mode == "spawn" {
                precondition(controller.url!.query == "token=split-token-complete")
                controller.restart()
                wait { controller.url != nil || controller.errorText != nil }
                precondition(controller.url != nil && controller.ownsBackend)
            }
        }
        controller.shutdown()
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        print("PASS \(mode)")
    }
}
