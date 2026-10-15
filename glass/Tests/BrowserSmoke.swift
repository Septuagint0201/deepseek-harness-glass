import AppKit
import WebKit

@main
struct BrowserSmoke {
    static func main() {
        _ = NSApplication.shared
        let url = URL(string: CommandLine.arguments[1])!
        var opened: [URL] = []
        let controller = GlassWebViewController(url: url, websiteDataStore: .nonPersistent(),
                                              openBrowser: { opened.append($0) })
        let webView = controller.view as! WKWebView
        // Scripted clicks lack the user's physical gesture in this test process.
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        func wait(_ predicate: () -> Bool) {
            let deadline = Date().addingTimeInterval(15)
            while !predicate(), Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            precondition(predicate(), "Browser handoff timed out")
        }
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
        wait { !webView.isLoading && webView.url == url }
        precondition(evaluate("window.pending = window.open('about:blank', '_blank'); Boolean(window.pending)"),
                     "Login must receive a live popup handle")
        precondition(opened.isEmpty, "about:blank must not open a browser")
        precondition(evaluate("window.pending.opener = null; window.pending.location.replace('https://example.invalid/authorize?fixture=1'); true"))
        wait { opened.count == 1 }
        precondition(opened[0].absoluteString == "https://example.invalid/authorize?fixture=1")

        precondition(evaluate("window.open('https://example.invalid/help', '_blank', 'noopener,noreferrer'); true"))
        wait { opened.count == 2 }
        precondition(opened[1].absoluteString == "https://example.invalid/help")
        precondition(evaluate("window.pending = window.open('about:blank', '_blank'); window.pending.close(); true"))
        precondition(evaluate("window.pending = window.open('about:blank', '_blank'); window.pending.location.replace('file:///tmp/blocked'); true"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        precondition(opened.count == 2, "Cancelled/unsupported popups must not open a browser")
        precondition(webView.url == url, "Browser handoff must preserve the main frontend")
        withExtendedLifetime(controller) {}
        print("PASS browser: asynchronous login, direct link, cancellation, unsupported scheme")
    }
}
