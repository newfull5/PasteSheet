import CoreGraphics
import ApplicationServices

final class KeySimulationService {

    /// Synthetic Cmd+V requires Accessibility (TCC) permission. Without it the
    /// posted CGEvent is silently dropped — the classic "window opens but paste
    /// does nothing" bug, especially after a rebuild changes the code signature.
    /// Returns true if trusted; prompts the user (once) and returns false otherwise.
    func ensureAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)
        // Key code 9 = 'V'
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
