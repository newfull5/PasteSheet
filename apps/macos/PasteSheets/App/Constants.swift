import Foundation
import CoreGraphics
import AppKit

enum Constants {
    // Design tokens (matches original Svelte/Tauri theme)
    static let accentColor = NSColor(red: 220/255, green: 220/255, blue: 87/255, alpha: 1.0)
    static let subTextColor = NSColor(red: 0x68/255, green: 0x74/255, blue: 0x8d/255, alpha: 1.0)
    static let bgContainer = NSColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 0.98)
    // Exact tokens from Tauri app.css / components
    static let modalDangerColor = NSColor(red: 0xef/255, green: 0x44/255, blue: 0x44/255, alpha: 1.0) // tailwind red-500 #ef4444
    static let detailModalBg = NSColor(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255, alpha: 1.0)    // #1e1e1e
    static let detailContentBg = NSColor(red: 0x1a/255, green: 0x1a/255, blue: 0x1a/255, alpha: 1.0)  // #1a1a1a
    static let dangerColor = NSColor(red: 1.0, green: 0x44/255, blue: 0x44/255, alpha: 1.0)        // #ff4444
    static let memoColor = NSColor(red: 0xe2/255, green: 0xe2/255, blue: 0xb6/255, alpha: 1.0)     // #e2e2b6
    static let clipboardPollingInterval: TimeInterval = 0.1
    static let mouseEdgePollingInterval: TimeInterval = 0.1
    static let mouseEdgeThreshold: CGFloat = 2.0
    static let windowWidth: CGFloat = 380.0
    static let windowMinHeight: CGFloat = 300.0
    static let windowMaxHeight: CGFloat = 1400.0
    static let windowHideAnimationDelay: TimeInterval = 0.35
    static let pasteRestoreDelay1: TimeInterval = 0.08
    static let pasteRestoreDelay2: TimeInterval = 0.05
    static let pasteToggleDelay: TimeInterval = 0.05
    static let mouseEdgeAutoHideDelay: TimeInterval = 0.15
    static let maxItemsPerDirectory: Int64 = 30
    static let defaultDirectory = "Clipboard"
    static let defaultShortcut = "CommandOrControl+Shift+V"
    static let defaultAutoHideTimeout = 5
}
