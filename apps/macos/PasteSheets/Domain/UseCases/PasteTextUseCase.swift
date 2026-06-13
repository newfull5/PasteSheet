import Foundation

final class PasteTextUseCase {
    private let clipboardService: ClipboardService
    private let previousAppService: PreviousAppService
    private let keySimService: KeySimulationService

    init(clipboardService: ClipboardService,
         previousAppService: PreviousAppService,
         keySimService: KeySimulationService) {
        self.clipboardService = clipboardService
        self.previousAppService = previousAppService
        self.keySimService = keySimService
    }

    /// Returns false if Accessibility permission is missing (paste aborted and
    /// the user was prompted to grant it); true once the paste was simulated.
    @discardableResult
    func execute(text: String) -> Bool {
        guard keySimService.ensureAccessibilityPermission() else { return false }

        clipboardService.setText(text)
        previousAppService.restoreAndWaitUntilFrontmost(
            timeout: Constants.pasteFocusTimeout,
            pollInterval: Constants.pasteFocusPollInterval
        )
        keySimService.simulatePaste()
        return true
    }
}
