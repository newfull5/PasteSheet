import AppKit

final class PreviousAppService {
    private var previousApp: NSRunningApplication?

    func saveCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp = app
    }

    /// Activate the previously-active app and poll until it actually becomes
    /// frontmost (or the timeout elapses), instead of relying on a fixed sleep.
    /// This is the macOS equivalent of waiting for `GetForegroundWindow` on
    /// Windows: fast Macs proceed in a few ms, slow Macs get the time they need.
    /// Must be called off the main thread (the poll loop sleeps).
    func restoreAndWaitUntilFrontmost(timeout: TimeInterval, pollInterval: TimeInterval) {
        guard let target = previousApp else { return }
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            activate(target)
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
                return
            }
            Thread.sleep(forTimeInterval: pollInterval)
        } while Date() < deadline
    }

    private func activate(_ app: NSRunningApplication?) {
        guard let app else { return }
        // AppKit activation must run on the main thread.
        DispatchQueue.main.sync {
            if #available(macOS 14.0, *) {
                // macOS 14+ cooperative activation: yield our activation so the
                // target app is allowed to come forward, then activate it.
                NSApp.yieldActivation(to: app)
                app.activate()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }
}
