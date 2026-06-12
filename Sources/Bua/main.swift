import AppKit

if CommandLine.arguments.contains("--probe") {
    let semaphore = DispatchSemaphore(value: 0)
    Task.detached {
        await Probe.run()
        semaphore.signal()
    }
    semaphore.wait()
    exit(0)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusController()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
