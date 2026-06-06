import AppKit

final class MouseEdgeService {
    private var timer: Timer?
    private var isEnabled = true
    private let positionService = WindowPositionService()

    func startMonitoring(
        windowWidth: CGFloat,
        isWindowVisible: @escaping () -> Bool,
        onEdgeReached: @escaping () -> Void,
        onEdgeLeft: @escaping () -> Void
    ) {
        timer = Timer.scheduledTimer(withTimeInterval: Constants.mouseEdgePollingInterval, repeats: true) { [weak self] _ in
            guard let self, self.isEnabled else { return }

            let mouse = self.positionService.mouseLocation()
            let rightEdge = self.positionService.rightEdgeX()
            let atRightEdge = mouse.x >= rightEdge - Constants.mouseEdgeThreshold
            let outsideWindow = mouse.x < rightEdge - windowWidth
            let visible = isWindowVisible()

            if atRightEdge && !visible {
                onEdgeReached()
            } else if outsideWindow && visible {
                onEdgeLeft()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
}
