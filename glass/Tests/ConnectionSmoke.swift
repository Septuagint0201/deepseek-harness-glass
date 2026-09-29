import AppKit
import Foundation

@main
struct ConnectionSmoke {
    static func main() {
        let args = CommandLine.arguments
        let mode = args[1]
        let controller = BackendController.shared
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
