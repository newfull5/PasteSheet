import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: MainPanel!
    private var statusItem: NSStatusItem!
    private var vm: AppViewModel!

    // Services
    private let clipboardService = ClipboardService()
    private let previousAppService = PreviousAppService()
    private let keySimService = KeySimulationService()
    private let hotkeyService = HotkeyService()
    private let mouseEdgeService = MouseEdgeService()
    private let autoStartService = AutoStartService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do { try DatabaseManager.shared.initialize() }
        catch { NSLog("DB init failed: \(error)"); return }

        let itemRepo = PasteItemRepositoryImpl()
        let dirRepo = DirectoryRepositoryImpl()
        let settingsRepo = SettingsRepositoryImpl()

        let settingsUseCase = SettingsUseCase(
            repo: settingsRepo,
            mouseEdgeService: mouseEdgeService,
            autoStartService: autoStartService
        )

        // First-run: enable auto-start
        if (try? settingsUseCase.getSetting(key: "auto_start")) == nil {
            try? settingsUseCase.setAutoStart(enabled: true)
        }

        // Apply mouse edge setting
        let edgeEnabled = (try? settingsUseCase.getSetting(key: "mouse_edge_enabled")) != "false"
        mouseEdgeService.setEnabled(edgeEnabled)

        vm = AppViewModel(
            manageItems: ManageItemsUseCase(repo: itemRepo),
            manageDirectories: ManageDirectoriesUseCase(repo: dirRepo),
            searchUseCase: SearchUseCase(),
            pasteText: PasteTextUseCase(
                clipboardService: clipboardService,
                previousAppService: previousAppService,
                keySimService: keySimService
            ),
            clipboardMonitor: ClipboardMonitorUseCase(
                itemRepo: itemRepo,
                clipboardService: clipboardService
            ),
            settingsUseCase: settingsUseCase,
            previousAppService: previousAppService,
            hotkeyService: hotkeyService
        )

        setupPanel()
        setupTray()
        setupHotkey(settingsUseCase: settingsUseCase)
        startBackgroundServices()
    }

    // MARK: - Panel

    private func setupPanel() {
        panel = MainPanel()
        vm.panel = panel

        let contentView = ContentView(vm: vm)
        panel.contentView = NSHostingView(rootView: contentView)

        panel.keyDownHandler = { [weak self] event in
            self?.vm.handleKeyDown(event: event) ?? false
        }

        // Close = hide
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak self] _ in
            self?.panel.orderOut(nil)
            self?.vm.isWindowVisible = false
        }
    }

    // MARK: - Tray

    private func setupTray() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let img = NSImage(named: "TrayIcon") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "PS"
            }
            button.action = #selector(trayClicked)
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show App", action: #selector(trayClicked), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit PasteSheet", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = nil // left-click = toggle, right-click = menu

        // Right-click menu via button sendAction
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func trayClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Show App", action: #selector(showFromMenu), keyEquivalent: ""))
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Quit PasteSheet", action: #selector(quitApp), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            previousAppService.saveCurrentApp()
            vm.toggleWindow()
        }
    }

    @objc private func showFromMenu() {
        vm.toggleWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Hotkey

    private func setupHotkey(settingsUseCase: SettingsUseCase) {
        let shortcut = (try? settingsUseCase.getSetting(key: "shortcut")) ?? Constants.defaultShortcut
        hotkeyService.register(shortcut: shortcut) { [weak self] in
            self?.previousAppService.saveCurrentApp()
            self?.vm.toggleWindow()
        }
    }

    // MARK: - Background Services

    private func startBackgroundServices() {
        vm.clipboardMonitor.startMonitoring { [weak self] in
            self?.vm.onClipboardUpdated()
        }

        mouseEdgeService.startMonitoring(
            windowWidth: Constants.windowWidth,
            isWindowVisible: { [weak self] in self?.vm.isWindowVisible ?? false },
            onEdgeReached: { [weak self] in
                DispatchQueue.main.async { self?.vm.showWindowFromEdge() }
            },
            onEdgeLeft: { [weak self] in
                DispatchQueue.main.async { self?.vm.hideWindowFromEdge() }
            }
        )
    }
}
