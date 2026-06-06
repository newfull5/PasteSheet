import AppKit

final class WindowPositionService {

    struct WindowPosition {
        let origin: NSPoint
        let height: CGFloat
    }

    func calculatePosition(windowWidth: CGFloat) -> WindowPosition? {
        guard let screen = activeScreen() else { return nil }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.maxX - windowWidth
        let y = visibleFrame.minY
        return WindowPosition(origin: NSPoint(x: x, y: y), height: visibleFrame.height)
    }

    func screenHeight() -> CGFloat {
        activeScreen()?.frame.height ?? 800
    }

    func mouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }

    func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
    }

    func rightEdgeX() -> CGFloat {
        activeScreen()?.frame.maxX ?? 0
    }
}
