import CoreGraphics

final class KeySimulationService {

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
