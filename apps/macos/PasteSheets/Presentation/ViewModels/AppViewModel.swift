import AppKit
import Combine

enum ViewType {
    case directories
    case items
    case settings
}

struct ModalConfig {
    let title: String
    let message: String
    let confirmText: String
    let cancelText: String
    let isDanger: Bool
    let showInput: Bool
    var inputValue: String
    let onConfirm: (String?) -> Void
}

final class AppViewModel: ObservableObject {
    // MARK: - State
    @Published var currentView: ViewType = .directories
    @Published var isWindowVisible = false
    @Published var searchQuery = ""
    @Published var selectedIndex = 0
    @Published var directories: [DirectoryInfo] = []
    @Published var allItems: [PasteItem] = []
    @Published var currentDirectory = ""
    @Published var editingItemId: Int64?
    @Published var editContent = ""
    @Published var editMemo = ""
    @Published var modalConfig: ModalConfig?
    @Published var detailItem: PasteItem?
    @Published var buttonFocusIndex = 0
    @Published var isAutoHideMode = false
    @Published var shouldFocusSearch = false

    // MARK: - Auto-hide
    private var autoHideEnabled = false
    private var autoHideTimeout = Constants.defaultAutoHideTimeout
    private var autoHideTimer: Timer?

    // MARK: - Dependencies
    let manageItems: ManageItemsUseCase
    let manageDirectories: ManageDirectoriesUseCase
    let searchUseCase: SearchUseCase
    let pasteText: PasteTextUseCase
    let clipboardMonitor: ClipboardMonitorUseCase
    let settingsUseCase: SettingsUseCase
    let previousAppService: PreviousAppService
    let hotkeyService: HotkeyService

    weak var panel: NSPanel?

    init(manageItems: ManageItemsUseCase,
         manageDirectories: ManageDirectoriesUseCase,
         searchUseCase: SearchUseCase,
         pasteText: PasteTextUseCase,
         clipboardMonitor: ClipboardMonitorUseCase,
         settingsUseCase: SettingsUseCase,
         previousAppService: PreviousAppService,
         hotkeyService: HotkeyService) {
        self.manageItems = manageItems
        self.manageDirectories = manageDirectories
        self.searchUseCase = searchUseCase
        self.pasteText = pasteText
        self.clipboardMonitor = clipboardMonitor
        self.settingsUseCase = settingsUseCase
        self.previousAppService = previousAppService
        self.hotkeyService = hotkeyService
    }

    // MARK: - Computed

    var filteredDirectories: [DirectoryInfo] {
        guard !searchQuery.isEmpty else { return directories }
        return searchUseCase.search(query: searchQuery, allItems: allItems, allDirectories: directories).directories
    }

    var filteredItems: [PasteItem] {
        if !searchQuery.isEmpty {
            return searchUseCase.search(query: searchQuery, allItems: allItems, allDirectories: directories).items
        }
        return allItems.filter { $0.directory == currentDirectory }
    }

    var listCount: Int {
        if !searchQuery.isEmpty {
            return filteredDirectories.count + filteredItems.count
        } else if currentView == .directories {
            return filteredDirectories.count + 1 // +1 for "New Folder"
        } else {
            return filteredItems.count + 1 // +1 for "New Item"
        }
    }

    // MARK: - View Navigation

    func showDirectoryView() {
        let lastDir = currentDirectory
        currentView = .directories
        searchQuery = ""
        if let idx = directories.firstIndex(where: { $0.name == lastDir }) {
            selectedIndex = idx
        } else {
            selectedIndex = 0
        }
        loadDirectories()
    }

    func showItemView(directoryName: String) {
        currentDirectory = directoryName
        currentView = .items
        searchQuery = ""
        selectedIndex = 0
        buttonFocusIndex = 0
        loadHistory()
    }

    func showSettingsView() {
        currentView = .settings
        searchQuery = ""
    }

    // MARK: - Data Loading

    func loadDirectories() {
        do {
            directories = try manageDirectories.getAllDirectories()
        } catch {
            NSLog("Failed to load directories: \(error)")
        }
    }

    func loadHistory() {
        do {
            allItems = try manageItems.getAllItems()
        } catch {
            NSLog("Failed to load history: \(error)")
        }
    }

    func onWindowBecameVisible() {
        loadDirectories()
        loadHistory()
        loadAutoHideSettings()
        resetAutoHideTimer()
        // Reset the directory list to the top so the Clipboard folder is visible on open
        if currentView == .directories && searchQuery.isEmpty {
            selectedIndex = 0
        }
    }

    func onClipboardUpdated() {
        loadDirectories()
        loadHistory()
    }

    // MARK: - Item Actions

    func pasteItem(_ item: PasteItem) {
        toggleWindow()
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + Constants.pasteToggleDelay) { [weak self] in
            self?.pasteText.execute(text: item.content)
        }
    }

    func startEdit(_ item: PasteItem) {
        editingItemId = item.id
        editContent = item.content
        editMemo = item.memo ?? ""
        currentDirectory = item.directory
    }

    func saveEdit() {
        guard let id = editingItemId else { return }
        do {
            try manageItems.updateItem(id: id, content: editContent, directory: currentDirectory, memo: editMemo.isEmpty ? nil : editMemo)
            editingItemId = nil
            loadHistory()
            loadDirectories()
        } catch {
            NSLog("Failed to save edit: \(error)")
        }
    }

    func cancelEdit() {
        editingItemId = nil
    }

    func createItem(content: String, memo: String?) {
        do {
            _ = try manageItems.createItem(content: content, directory: currentDirectory, memo: memo)
            loadHistory()
            loadDirectories()
        } catch {
            NSLog("Failed to create item: \(error)")
        }
    }

    func deleteItem(id: Int64) {
        modalConfig = ModalConfig(
            title: "Delete Item",
            message: "Are you sure you want to delete this item?",
            confirmText: "Delete",
            cancelText: "Cancel",
            isDanger: true,
            showInput: false,
            inputValue: "",
            onConfirm: { [weak self] _ in
                do {
                    try self?.manageItems.deleteItem(id: id)
                    self?.loadHistory()
                    self?.loadDirectories()
                } catch {
                    NSLog("Failed to delete item: \(error)")
                }
            }
        )
    }

    // MARK: - Directory Actions

    func createDirectory(name: String) {
        do {
            _ = try manageDirectories.createDirectory(name: name)
            loadDirectories()
        } catch {
            NSLog("Failed to create directory: \(error)")
        }
    }

    func renameDirectory(oldName: String) {
        modalConfig = ModalConfig(
            title: "Rename Folder",
            message: "Enter new name for the folder:",
            confirmText: "Rename",
            cancelText: "Cancel",
            isDanger: false,
            showInput: true,
            inputValue: oldName,
            onConfirm: { [weak self] newName in
                guard let newName, !newName.isEmpty, newName != oldName else { return }
                do {
                    try self?.manageDirectories.renameDirectory(oldName: oldName, newName: newName)
                    self?.loadDirectories()
                } catch {
                    NSLog("Failed to rename directory: \(error)")
                }
            }
        )
    }

    func deleteDirectory(name: String) {
        modalConfig = ModalConfig(
            title: "Delete Folder",
            message: "Are you sure you want to delete folder \"\(name)\"? All items inside will be lost.",
            confirmText: "Delete",
            cancelText: "Cancel",
            isDanger: true,
            showInput: false,
            inputValue: "",
            onConfirm: { [weak self] _ in
                do {
                    try self?.manageDirectories.deleteDirectory(name: name)
                    self?.loadDirectories()
                } catch {
                    NSLog("Failed to delete directory: \(error)")
                }
            }
        )
    }

    // MARK: - Window

    func toggleWindow() {
        guard let panel else { return }
        if isWindowVisible {
            isWindowVisible = false
            isAutoHideMode = false
            clearAutoHideTimer()
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = Constants.windowHideAnimationDelay
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard self?.isWindowVisible == false else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
            })
        } else {
            let posService = WindowPositionService()
            if let pos = posService.calculatePosition(windowWidth: Constants.windowWidth) {
                panel.setFrame(NSRect(x: pos.origin.x, y: pos.origin.y, width: Constants.windowWidth, height: pos.height), display: true)
            }
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
            isWindowVisible = true
            onWindowBecameVisible()
        }
    }

    func showWindowFromEdge() {
        guard let panel, !isWindowVisible else { return }
        let posService = WindowPositionService()
        if let pos = posService.calculatePosition(windowWidth: Constants.windowWidth) {
            panel.setFrame(NSRect(x: pos.origin.x, y: pos.origin.y, width: Constants.windowWidth, height: pos.height), display: true)
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        panel.makeKey()
        isWindowVisible = true
        isAutoHideMode = true
        onWindowBecameVisible()
    }

    func hideWindowFromEdge() {
        guard isWindowVisible, isAutoHideMode else { return }
        isWindowVisible = false
        isAutoHideMode = false
        clearAutoHideTimer()
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.mouseEdgeAutoHideDelay) { [weak self] in
            guard self?.isWindowVisible == false else { return }
            self?.panel?.orderOut(nil)
        }
    }

    // MARK: - Auto-hide Timer

    func resetAutoHideTimer() {
        guard autoHideEnabled, isWindowVisible else { return }
        clearAutoHideTimer()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(autoHideTimeout), repeats: false) { [weak self] _ in
            self?.toggleWindow()
        }
    }

    func clearAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    private func loadAutoHideSettings() {
        autoHideEnabled = (try? settingsUseCase.getSetting(key: "auto_hide_enabled")) == "true"
        if let val = try? settingsUseCase.getSetting(key: "auto_hide_timeout"), let t = Int(val) {
            autoHideTimeout = t
        }
    }

    // MARK: - Keyboard

    func handleKeyDown(event: NSEvent) -> Bool {
        resetAutoHideTimer()

        let fr = panel?.firstResponder
        let isInput = fr is NSTextView || fr is NSTextField
        let hasCmd = event.modifierFlags.contains(.command)
        let msg = "[VM] key=\(event.keyCode) isInput=\(isInput) view=\(currentView) idx=\(selectedIndex) count=\(listCount) fr=\(String(describing: fr))\n"
        FileHandle.standardError.write(Data(msg.utf8))

        // Escape chain
        if event.keyCode == 53 { // Escape
            if modalConfig != nil { modalConfig = nil; return true }
            if detailItem != nil { detailItem = nil; return true }
            if editingItemId != nil { editingItemId = nil; return true }
            if currentView == .settings { showDirectoryView(); return true }
            if !searchQuery.isEmpty { searchQuery = ""; return true }
            toggleWindow()
            return true
        }

        if modalConfig != nil { return false }
        if detailItem != nil { return false }

        // Cmd+Enter to save edit
        if editingItemId != nil && isInput && event.keyCode == 36 && hasCmd {
            saveEdit()
            return true
        }

        // Arrow keys always navigate, even when search field is focused
        switch event.keyCode {
        case 125: // Down
            selectedIndex = (selectedIndex + 1) % max(listCount, 1)
            buttonFocusIndex = 0
            return true
        case 126: // Up
            selectedIndex = (selectedIndex - 1 + max(listCount, 1)) % max(listCount, 1)
            buttonFocusIndex = 0
            return true
        case 124: // Right
            if !searchQuery.isEmpty { return false }
            if currentView == .directories {
                let dirs = filteredDirectories
                if selectedIndex < dirs.count {
                    showItemView(directoryName: dirs[selectedIndex].name)
                    return true
                }
            } else if currentView == .items && buttonFocusIndex < 2 {
                buttonFocusIndex += 1
                return true
            }
        case 123: // Left
            if !searchQuery.isEmpty { return false }
            if currentView == .items {
                if buttonFocusIndex > 0 {
                    buttonFocusIndex -= 1
                    return true
                }
                showDirectoryView()
                return true
            } else if currentView == .settings {
                showDirectoryView()
                return true
            }
        default: break
        }

        // Enter (always handle, even when search field focused)
        if event.keyCode == 36 && (editingItemId == nil || !isInput) {
            if !searchQuery.isEmpty {
                executeSearchAction()
                return true
            }
            if currentView == .directories {
                let dirs = filteredDirectories
                if selectedIndex < dirs.count {
                    showItemView(directoryName: dirs[selectedIndex].name)
                }
                return true
            }
            if currentView == .items {
                executeItemAction()
                return true
            }
        }

        // Space - detail view
        if event.keyCode == 49 && !isInput && currentView == .items && searchQuery.isEmpty {
            let items = filteredItems
            if selectedIndex < items.count {
                detailItem = items[selectedIndex]
            }
            return true
        }

        // Auto-focus search on character input
        if !isInput && !hasCmd && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
            if let chars = event.characters, chars.count == 1, chars.first!.isLetter || chars.first!.isNumber {
                shouldFocusSearch = true
                return false
            }
        }

        // Cmd+Backspace - delete
        if event.keyCode == 51 && hasCmd && !isInput {
            if !searchQuery.isEmpty {
                let dirs = filteredDirectories
                if selectedIndex < dirs.count {
                    deleteDirectory(name: dirs[selectedIndex].name)
                } else {
                    let itemIdx = selectedIndex - dirs.count
                    let items = filteredItems
                    if itemIdx < items.count { deleteItem(id: items[itemIdx].id) }
                }
            } else if currentView == .directories {
                let dirs = filteredDirectories
                if selectedIndex < dirs.count { deleteDirectory(name: dirs[selectedIndex].name) }
            } else if currentView == .items {
                let items = filteredItems
                if selectedIndex < items.count { deleteItem(id: items[selectedIndex].id) }
            }
            return true
        }

        return false
    }

    private func executeSearchAction() {
        let dirs = filteredDirectories
        if selectedIndex < dirs.count {
            showItemView(directoryName: dirs[selectedIndex].name)
        } else {
            let itemIdx = selectedIndex - dirs.count
            let items = filteredItems
            if itemIdx < items.count {
                executeActionOnItem(items[itemIdx])
            }
        }
    }

    private func executeItemAction() {
        let items = filteredItems
        if selectedIndex < items.count {
            executeActionOnItem(items[selectedIndex])
        }
    }

    private func executeActionOnItem(_ item: PasteItem) {
        switch buttonFocusIndex {
        case 0: pasteItem(item)
        case 1: startEdit(item)
        case 2: deleteItem(id: item.id)
        default: break
        }
    }
}
