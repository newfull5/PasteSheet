import AppKit

final class MainPanel: NSPanel {

    var keyDownHandler: ((NSEvent) -> Bool)?

    init() {
        let height = UserDefaults.standard.double(forKey: "windowHeight")
        let initialHeight = height >= Constants.windowMinHeight ? height : 800

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Constants.windowWidth, height: initialHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let msg = "[MainPanel] keyDown: code=\(event.keyCode), firstResponder=\(type(of: firstResponder))\n"
            FileHandle.standardError.write(Data(msg.utf8))
            if let handler = keyDownHandler, handler(event) {
                return
            }
        }
        super.sendEvent(event)
    }

    func saveHeight() {
        UserDefaults.standard.set(frame.height, forKey: "windowHeight")
    }
}
