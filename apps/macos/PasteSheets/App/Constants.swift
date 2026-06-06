import Foundation
import CoreGraphics
import AppKit

enum Constants {
    // Design tokens (matches original Svelte/Tauri theme)
    static let accentColor = NSColor(red: 220/255, green: 220/255, blue: 87/255, alpha: 1.0)
    static let subTextColor = NSColor(red: 0x68/255, green: 0x74/255, blue: 0x8d/255, alpha: 1.0)
    static let bgContainer = NSColor(red: 18/255, green: 18/255, blue: 18/255, alpha: 0.98)
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
