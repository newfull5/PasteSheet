import Foundation

final class ClipboardMonitorUseCase {
    private let itemRepo: PasteItemRepository
    private let clipboardService: ClipboardService
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    init(itemRepo: PasteItemRepository, clipboardService: ClipboardService) {
        self.itemRepo = itemRepo
        self.clipboardService = clipboardService
    }

    func startMonitoring(onChange: @escaping () -> Void) {
        lastChangeCount = clipboardService.currentChangeCount()
        timer = Timer.scheduledTimer(withTimeInterval: Constants.clipboardPollingInterval, repeats: true) { [weak self] _ in
            self?.poll(onChange: onChange)
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func poll(onChange: @escaping () -> Void) {
        guard clipboardService.hasChanged(since: lastChangeCount) else { return }
        lastChangeCount = clipboardService.currentChangeCount()

        guard let text = clipboardService.getText(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            if let existing = try itemRepo.findByContent(text, directory: Constants.defaultDirectory) {
                try itemRepo.updateItem(
                    id: existing.id,
                    content: text,
                    directory: Constants.defaultDirectory,
                    memo: existing.memo
                )
            } else {
                _ = try itemRepo.createItem(content: text, directory: Constants.defaultDirectory, memo: nil)
                try itemRepo.cleanupOldItems(
                    directory: Constants.defaultDirectory,
                    maxCount: Constants.maxItemsPerDirectory
                )
            }
            DispatchQueue.main.async { onChange() }
        } catch {
            NSLog("ClipboardMonitor error: \(error)")
        }
    }
}
