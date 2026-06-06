import AppKit

final class ClipboardService {
    private let pasteboard = NSPasteboard.general

    func getText() -> String? {
        pasteboard.string(forType: .string)
    }

    func setText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func hasChanged(since lastChangeCount: Int) -> Bool {
        pasteboard.changeCount != lastChangeCount
    }

    func currentChangeCount() -> Int {
        pasteboard.changeCount
    }
}
