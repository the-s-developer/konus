import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = StatusMenuController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.setup()
        NSLog("[konus] Konus started. Press F1 to toggle.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.manager.stop()
    }
}

@main
struct KonusApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // No dock icon

        let delegate = AppDelegate()
        app.delegate = delegate

        // Keep delegate alive
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
