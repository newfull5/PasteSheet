import Foundation
import CoreGraphics
import AppKit

enum Constants {
    // MARK: - Legacy tokens (Svelte/Tauri theme — migrate per-screen)
    static let accentColor = NSColor(red: 220/255, green: 220/255, blue: 87/255, alpha: 1.0)
    static let subTextColor = NSColor(red: 0x68/255, green: 0x74/255, blue: 0x8d/255, alpha: 1.0)
    static let bgContainer = NSColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 0.98)
    static let modalDangerColor = NSColor(red: 0xef/255, green: 0x44/255, blue: 0x44/255, alpha: 1.0)
    static let detailModalBg = NSColor(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255, alpha: 1.0)
    static let detailContentBg = NSColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1.0)
    static let dangerColor = NSColor(red: 1.0, green: 0x44/255, blue: 0x44/255, alpha: 1.0)
    static let memoColor = NSColor(red: 0xe2/255, green: 0xe2/255, blue: 0xb6/255, alpha: 1.0)

    // MARK: - Design tokens v2 (UI Redesign)
    static let accentPrimary = NSColor(red: 199/255, green: 202/255, blue: 70/255, alpha: 1.0)     // #C7CA46 calm gold
    static let focusBorder = NSColor(red: 185/255, green: 188/255, blue: 68/255, alpha: 1.0)       // #B9BC44
    static let textPrimary = NSColor(red: 237/255, green: 237/255, blue: 232/255, alpha: 1.0)      // #EDEDE8
    static let textSecondary = NSColor(red: 154/255, green: 154/255, blue: 146/255, alpha: 1.0)    // #9a9a92
    static let textTertiary = NSColor(red: 124/255, green: 124/255, blue: 116/255, alpha: 1.0)     // #7c7c74
    static let surface = NSColor(red: 35/255, green: 35/255, blue: 32/255, alpha: 1.0)             // #232320
    static let panelBg = NSColor(red: 27/255, green: 27/255, blue: 25/255, alpha: 1.0)             // #1b1b19
    static let neutralBorder = NSColor(white: 1.0, alpha: 0.10)
    static let dividerColor = NSColor(white: 1.0, alpha: 0.06)
    static let danger = NSColor(red: 226/255, green: 75/255, blue: 74/255, alpha: 1.0)             // #E24B4A
    static let dangerText = NSColor(red: 216/255, green: 90/255, blue: 48/255, alpha: 1.0)         // #D85A30
    static let radiusControl: CGFloat = 8
    static let radiusCard: CGFloat = 12
    static let clipboardPollingInterval: TimeInterval = 0.1
    static let mouseEdgePollingInterval: TimeInterval = 0.1
    static let mouseEdgeThreshold: CGFloat = 2.0
    static let windowWidth: CGFloat = 380.0
    static let windowMinHeight: CGFloat = 300.0
    static let windowMaxHeight: CGFloat = 1400.0
    // Panel slide animation — source of truth: config/animation.json
    static let panelSlideDuration: TimeInterval = 0.190
    static let panelSlideOffset: CGFloat = 48.0
    static let windowHideAnimationDelay: TimeInterval = 0.35
    static let pasteToggleDelay: TimeInterval = 0.05
    // Focus restore: poll until the previous app is frontmost instead of a fixed
    // sleep, so fast Macs paste sooner and slow Macs get enough time.
    static let pasteFocusTimeout: TimeInterval = 0.3
    static let pasteFocusPollInterval: TimeInterval = 0.005
    static let mouseEdgeAutoHideDelay: TimeInterval = 0.15
    static let maxItemsPerDirectory: Int64 = 30
    static let defaultDirectory = "Clipboard"
    static let defaultShortcut = "CommandOrControl+Shift+V"
    static let defaultAutoHideTimeout = 5
}
