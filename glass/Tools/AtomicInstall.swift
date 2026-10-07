import Foundation
import Darwin

// Both bundles are on the destination filesystem. Swapping their directory
// entries keeps the installed path present and leaves the old app at stage.
@main
struct AtomicInstall {
    static func main() {
        guard CommandLine.arguments.count == 3 else {
            fputs("usage: atomic-install <staged.app> <installed.app>\n", stderr)
            exit(2)
        }
        let stage = CommandLine.arguments[1]
        let destination = CommandLine.arguments[2]
        guard stage.hasSuffix(".app"), destination.hasSuffix(".app") else {
            fputs("Both installation paths must end in .app\n", stderr)
            exit(2)
        }
        let exists = FileManager.default.fileExists(atPath: destination)
        let result = stage.withCString { source in
            destination.withCString { target in
                renameatx_np(AT_FDCWD, source, AT_FDCWD, target,
                             exists ? UInt32(RENAME_SWAP) : UInt32(RENAME_EXCL))
            }
        }
        guard result == 0 else {
            let error = errno
            fputs("App installation failed; previous app preserved: \(String(cString: strerror(error)))\n", stderr)
            exit(1)
        }
    }
}
