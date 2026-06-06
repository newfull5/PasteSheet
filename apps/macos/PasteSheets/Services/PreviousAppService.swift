import AppKit

final class PreviousAppService {
    private var previousApp: NSRunningApplication?

    func saveCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        previousApp = app
    }

    func restorePreviousApp() {
        previousApp?.activate(options: [.activateIgnoringOtherApps])
    }
}
