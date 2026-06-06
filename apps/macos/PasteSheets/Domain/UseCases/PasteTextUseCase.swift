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

    func execute(text: String) {
        clipboardService.setText(text)

        previousAppService.restorePreviousApp()
        Thread.sleep(forTimeInterval: Constants.pasteRestoreDelay1)

        previousAppService.restorePreviousApp()
        Thread.sleep(forTimeInterval: Constants.pasteRestoreDelay2)

        keySimService.simulatePaste()
    }
}
