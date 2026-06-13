# PasteSheets macOS App — Complete Feature & Design Specification (v0.4.1)

Source of truth for the Windows port. All values extracted from
`/Users/saechan/RustProjects/PasteSheets/apps/macos/PasteSheets/**/*.swift` (41 files, 2,915 lines),
`Resources/Info.plist`, and `Resources/PasteSheets.entitlements`.

App identity: bundle id `com.newfull5.pastesheet`, name `PasteSheet`, version `0.4.1` (build 3),
minimum macOS 13.0, `LSUIElement = true` (no Dock icon) — `Resources/Info.plist:5-20`.
Activation policy `.accessory` set at launch — `App/AppDelegate.swift:19`.

---

## 1. Features

### 1.1 Clipboard Monitoring

File: `Domain/UseCases/ClipboardMonitorUseCase.swift`, `Services/ClipboardService.swift`

- **Polling**: `Timer` every **0.1 s** (`Constants.clipboardPollingInterval`, `App/Constants.swift:16`); compares `NSPasteboard.general.changeCount` against the last seen count (`ClipboardMonitorUseCase.swift:14-19, 26-28`; `ClipboardService.swift:15-21`). No OS notification — pure polling.
- **Captured types**: plain text only (`NSPasteboard .string` type, `ClipboardService.swift:6-8`). Images/files/RTF are ignored.
- **Empty filter**: skip if text trimmed of whitespace+newlines is empty (`ClipboardMonitorUseCase.swift:30-31`). The **original, untrimmed** text is what gets stored.
- **Dedup rule**: look up an item with **exactly identical content** in the default directory `"Clipboard"` (`findByContent`, SQL `WHERE content = ?1 AND directory = ?2 LIMIT 1`, `Data/DataSources/PasteItemDataSource.swift:42-48`). 
  - If found → `updateItem` with the same content/directory/memo; the UPDATE sets `created_at = CURRENT_TIMESTAMP`, which **bumps the item to the top** of the list (`ClipboardMonitorUseCase.swift:34-40`; `PasteItemDataSource.swift:31-36`).
  - If not found → insert new item with `memo = NULL` into `"Clipboard"` (`ClipboardMonitorUseCase.swift:41-42`).
- **Max items**: after insert, `cleanupOldItems(directory: "Clipboard", maxCount: 30)` (`Constants.maxItemsPerDirectory = 30`, `Constants.swift:27`). If count > 30, delete the oldest `count − 30` rows ordered `created_at ASC` (`Domain/Repositories/PasteItemRepository.swift:39-44`; delete SQL `PasteItemDataSource.swift:60-72`). The cap applies **only to the "Clipboard" directory and only on clipboard capture** — manually created items in other folders are never pruned (`AppViewModel.createItem` has no cleanup call, `Presentation/ViewModels/AppViewModel.swift:197-205`).
- **On change**: dispatch to main thread → `vm.onClipboardUpdated()` → reload directories + all items (`AppViewModel.swift:160-163`; wired in `AppDelegate.swift:152-154`).
- Errors are logged via `NSLog` and swallowed (`ClipboardMonitorUseCase.swift:49-50`).

### 1.2 Directory (Folder) Management

Files: `Data/DataSources/DirectoryDataSource.swift`, `Domain/UseCases/ManageDirectoriesUseCase.swift`, `AppViewModel.swift:230-278`

- **Default directory**: `"Clipboard"` (`Constants.defaultDirectory`, `Constants.swift:28`), seeded at DB init with `INSERT OR IGNORE` (`Data/Database/DatabaseSchema.swift:31-33`).
- **Ordering**: `ORDER BY CASE WHEN d.name = 'Clipboard' THEN 0 ELSE 1 END, d.created_at` — Clipboard always first, then creation order (`DirectoryDataSource.swift:21`). Each row carries an item count via `LEFT JOIN paste_sheets ... COUNT(p.id) ... GROUP BY d.name` (`DirectoryDataSource.swift:16-22`).
- **Create**: name trimmed with `.whitespaces`; empty → error `"Directory name cannot be empty"` (`DirectoryDataSource.swift:32-39, 77`). Duplicates rejected by `UNIQUE` constraint on `directories.name` (schema). **No max length constraint.** Triggered from the inline "New Folder" row (mouse click only, `Presentation/Views/DirectoryListView.swift:42-79`).
- **Rename**: both names trimmed; rejected if old name or new name == `"Clipboard"` or new name empty (error `"Cannot modify the Clipboard directory"`) (`DirectoryDataSource.swift:41-48, 78`). Executed in a transaction with `PRAGMA foreign_keys = OFF` → update `directories.name` → update `paste_sheets.directory` → `PRAGMA foreign_keys = ON` (`DirectoryDataSource.swift:50-61`). UI trigger: right-click context menu → "Rename" → confirm modal with text input prefilled with the old name; no-op if new name empty or unchanged (`AppViewModel.renameDirectory`, `AppViewModel.swift:239-258`; `DirectoryListView.swift:19-24`).
- **Delete**: rejected for `"Clipboard"`; deletes **all items in the folder first**, then the folder row (`DirectoryDataSource.swift:64-68`). UI triggers: context menu "Delete", or **Cmd+Backspace** on the selected row; always preceded by a danger confirm modal: title `"Delete Folder"`, message `Are you sure you want to delete folder "<name>"? All items inside will be lost.` (`AppViewModel.swift:260-278`).
- **Orphan sync**: at startup, any `paste_sheets.directory` value missing from `directories` is re-inserted (`DatabaseSchema.syncOrphanDirectories`, `DatabaseSchema.swift:43-46`; called `DatabaseManager.swift:31`).

### 1.3 Item Management

Files: `Data/DataSources/PasteItemDataSource.swift`, `AppViewModel.swift:167-226`

- **Ordering**: all items fetched globally with `ORDER BY created_at DESC` (newest first) (`PasteItemDataSource.swift:17-22`); the item view filters in memory by `directory == currentDirectory` (`AppViewModel.filteredItems`, `AppViewModel.swift:84-89`).
- **Manual create** ("New Item" row, mouse click only): optional memo + content `TextEditor`. Content trimmed with `.whitespacesAndNewlines`; empty content → not saved. Memo stored as `NULL` when empty (`Presentation/Views/ItemListView.swift:53-111`; `AppViewModel.createItem`, `AppViewModel.swift:197-205`). Saved into the currently open directory.
- **Edit (inline)**: `startEdit` copies item content/memo into `editContent`/`editMemo` and sets `currentDirectory = item.directory` (`AppViewModel.swift:174-179`). `saveEdit` runs `UPDATE ... SET content, directory, memo, created_at = CURRENT_TIMESTAMP` (memo `NULL` if empty) — so **editing bumps the item to the top** (`AppViewModel.swift:181-191`; SQL `PasteItemDataSource.swift:31-36`). Cancel just clears `editingItemId` (`AppViewModel.swift:193-195`).
- **Memo**: free-text label per item; nullable column; displayed above content in color `#e2e2b6`.
- **Delete**: always via danger confirm modal: title `"Delete Item"`, message `"Are you sure you want to delete this item?"`, buttons Delete/Cancel (`AppViewModel.deleteItem`, `AppViewModel.swift:207-226`).
- **Move between folders**: no dedicated UI. The update API supports changing `directory`, but the app never exposes it (edit keeps the item's own directory).

### 1.4 Search

Files: `Domain/UseCases/SearchUseCase.swift`, `AppViewModel.swift:79-99, 454-463`, `Presentation/Components/HeaderView.swift`

- **Trigger**: typing any **single letter or number** while no text input is focused — the character is appended to `searchQuery` immediately and the hidden search field is focused (`shouldFocusSearch = true`), so the first keystroke is never lost (`AppViewModel.swift:454-463`). The header title doubles as the search field (placeholder `"Search Anything..."`, `HeaderView.swift:60`). There is **no separate search box or button**.
- **Scope**: global across all folders. Directories matched on `name`, items matched on `content` **or** `memo` (`SearchUseCase.swift:10-21`).
- **Matching**: case-insensitive substring (`lowercased().contains`) — no fuzzy/regex/token logic.
- **Debounce**: **none** — `filteredDirectories`/`filteredItems` are computed properties re-evaluated on every keystroke (`AppViewModel.swift:79-89`). On every query change, `selectedIndex` resets to 0 (`HeaderView.swift:66-68`).
- **Activation**: whenever `searchQuery` is non-empty, `SearchResultView` replaces the current view and the header title shows `"Search results"` (`ContentView.swift:17-18`; `HeaderView.swift:14-15`). Esc clears the query (see Escape chain).
- Search results list = matching folders first, then matching items (`SearchResultView.swift`); `selectedIndex` spans both sections (`listCount = dirs + items`, `AppViewModel.swift:91-94`).

### 1.5 Paste Flow

Files: `AppViewModel.pasteItem` (`AppViewModel.swift:167-172`), `Domain/UseCases/PasteTextUseCase.swift`, `Services/KeySimulationService.swift`, `Services/PreviousAppService.swift`

Exact sequence when a paste is triggered (Enter with Paste button focused, or clicking "Paste"):

1. `toggleWindow()` — hides the panel: `isWindowVisible = false`, fade `alphaValue → 0` over **0.35 s** (`Constants.windowHideAnimationDelay`), then `orderOut` + reset alpha (`AppViewModel.swift:282-295`).
2. Wait **0.05 s** (`Constants.pasteToggleDelay`) on a background queue (`DispatchQueue.global(qos: .userInitiated).asyncAfter`) (`AppViewModel.swift:169`).
3. Write the item content to the system clipboard: `clearContents()` + `setString(_:forType:.string)` (`PasteTextUseCase.swift:17`; `ClipboardService.swift:10-13`).
4. Restore focus to the previously frontmost app: `previousApp.activate(options: [.activateIgnoringOtherApps])` (`PasteTextUseCase.swift:19`; `PreviousAppService.swift:12-14`).
5. Sleep **0.08 s** (`Constants.pasteRestoreDelay1`).
6. Restore the previous app **again** (double-activation for reliability) (`PasteTextUseCase.swift:22`).
7. Sleep **0.05 s** (`Constants.pasteRestoreDelay2`).
8. Simulate **Cmd+V**: `CGEvent` keyDown + keyUp with `virtualKey 9` ('V') and `flags = .maskCommand`, posted to `.cghidEventTap` with a `.hidSystemState` event source (`KeySimulationService.swift:5-14`).

Notes:
- The previous app is captured (`saveCurrentApp`) at hotkey press and tray left-click — frontmost app saved unless it is PasteSheets itself (`PreviousAppService.swift:6-10`; `AppDelegate.swift:126, 144-145`).
- The clipboard is **not restored** after pasting; the pasted text stays on the clipboard (and the monitor then dedup-bumps it in "Clipboard").
- Key simulation requires Accessibility permission on macOS (the hotkey itself does not — see below).

### 1.6 Global Hotkey

File: `Services/HotkeyService.swift`

- **Default combo**: `"CommandOrControl+Shift+V"` (`Constants.defaultShortcut`, `Constants.swift:29`) = **Cmd+Shift+V** on macOS. Stored/read from setting key `shortcut`; registered once at launch (`AppDelegate.swift:141-148`).
- **Registration method**: Carbon `RegisterEventHotKey` (NOT a CGEvent tap) — explicitly chosen because it requires **no Accessibility permission** (`HotkeyService.swift:4-9, 24-38`). HotKey ID: signature `0x50535448` ('PSTH'), id `1` (`HotkeyService.swift:14`). Event handler installed for `kEventClassKeyboard`/`kEventHotKeyPressed` on the application event target (`HotkeyService.swift:57-92`).
- **Action**: save frontmost app, then `toggleWindow()` (`AppDelegate.swift:143-147`).
- **Shortcut string parsing**: `+`-separated tokens; `CommandOrControl|Command|Cmd → cmdKey`, `Shift → shiftKey`, `Alt|Option → optionKey`, `Control|Ctrl → controlKey`; the remaining token maps to a Carbon virtual key code via a hardcoded map (A=0, S=1, D=2, F=3, H=4, G=5, Z=6, X=7, C=8, V=9, B=11, Q=12, W=13, E=14, R=15, Y=16, T=17, 1=18, 2=19, 3=20, 4=21, 6=22, 5=23, 9=25, 7=26, 8=28, 0=29, O=31, U=32, I=34, P=35, L=37, J=38, K=40, N=45, M=46; unknown → 0) (`HotkeyService.swift:96-126`).
- `updateShortcut(_:handler:)` exists (`HotkeyService.swift:49-55`) but is **never called** — the Settings "record shortcut" button only toggles a visual `isRecording` state; actual capture/rebinding is not implemented (`SettingsView.swift:27-36`).

### 1.7 Mouse Edge Peek

Files: `Services/MouseEdgeService.swift`, `Services/WindowPositionService.swift`, `AppViewModel.swift:310-333`, wiring `AppDelegate.swift:156-165`

- **Edge**: **right edge** of the screen the mouse is currently on (multi-monitor aware: screen = first screen whose frame contains the mouse, else `NSScreen.main`, `WindowPositionService.swift:26-30`).
- **Polling interval**: **0.1 s** (`Constants.mouseEdgePollingInterval`, `Constants.swift:17`).
- **Show rule**: `mouse.x >= screenRightEdgeX − 2.0` (`Constants.mouseEdgeThreshold = 2.0`, `Constants.swift:18`) while window hidden → `showWindowFromEdge()` (`MouseEdgeService.swift:19, 23-24`).
  - Show-from-edge places the panel (right-edge position, see §1.8), `alphaValue = 1`, `orderFrontRegardless()`, `makeKey()`, sets `isAutoHideMode = true`. **Does not call `NSApp.activate`** (unlike hotkey/tray show) (`AppViewModel.swift:310-322`).
- **Hide rule**: `mouse.x < screenRightEdgeX − windowWidth(380)` (mouse left the window's horizontal band) while window visible → `hideWindowFromEdge()` (`MouseEdgeService.swift:20, 25-26`). Only hides when `isAutoHideMode == true` (i.e., the window was opened by edge peek; a hotkey-opened window is never auto-hidden by mouse position) (`AppViewModel.swift:324-333`). Hide is instant `orderOut` after a **0.15 s** delay (`Constants.mouseEdgeAutoHideDelay`, `Constants.swift:26`) — no fade.
- **Enable/disable**: setting `mouse_edge_enabled` (DB default `'true'`); toggling applies immediately via `MouseEdgeService.setEnabled` (`Domain/UseCases/SettingsUseCase.swift:20-26`). On boot, treated enabled unless value is exactly `"false"` (`AppDelegate.swift:40-41`).

### 1.8 Window

Files: `Presentation/Views/MainPanel.swift`, `Services/WindowPositionService.swift`, `AppViewModel.swift:282-333`, `ContentView.swift:65-104`

- **Type**: `NSPanel` subclass with `styleMask = [.borderless, .nonactivatingPanel]` (`MainPanel.swift:11-16`). `isFloatingPanel = true`, `level = .floating`, `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = true`, `isMovableByWindowBackground = false`, `hidesOnDeactivate = false`, `isReleasedWhenClosed = false` (`MainPanel.swift:18-26`). `canBecomeKey = true`, `canBecomeMain = false` (`MainPanel.swift:29-30`).
- **Spaces/fullscreen**: `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` — appears on every Space and over fullscreen apps (`MainPanel.swift:23`).
- **Size**: width fixed **380 pt** (`Constants.windowWidth`). Initial height = persisted `UserDefaults "windowHeight"` if ≥ 300, else **800** (`MainPanel.swift:8-9`). Height clamp: min **300**, max **1400** (`Constants.windowMinHeight/MaxHeight`, `Constants.swift:20-21`).
- **Resizing**: vertical only, via a custom drag handle at the bottom of the content (12 pt tall strip with a 32×3 capsule). Drag delta = `−translation.height` applied to height, clamped 300–1400; on drag end the height is saved to `UserDefaults "windowHeight"` (`ContentView.swift:65-104`; `MainPanel.saveHeight`, `MainPanel.swift:43-45`). No OS resize borders.
- **Positioning on every show**: x = `visibleFrame.maxX − 380`, y = `visibleFrame.minY`, height = `visibleFrame.height` of the active (mouse) screen — i.e. the panel is **snapped flush to the right edge, full visible height** (excluding menu bar/Dock) every time it is shown (`WindowPositionService.swift:10-16`; applied in `toggleWindow`/`showWindowFromEdge`, `AppViewModel.swift:297-300, 312-315`). The user-resized height therefore only persists until the next show.
- **Show (hotkey/tray)**: set frame → `alphaValue = 1` → `orderFrontRegardless()` → `NSApp.activate(ignoringOtherApps: true)` → `makeKey()` → `onWindowBecameVisible()` (`AppViewModel.swift:296-307`).
- **Hide**: fade `alpha 1 → 0` over **0.35 s**, then `orderOut` (state preserved; never `close()`) (`AppViewModel.swift:284-295`). Window close notification is also mapped to hide (`AppDelegate.swift:83-87`).
- **On become visible**: reload directories + items, reload auto-hide settings, restart auto-hide timer, clear `searchQuery`, reset `selectedIndex = 0` if on directory view (`AppViewModel.onWindowBecameVisible`, `AppViewModel.swift:147-158`). The search field is explicitly defocused when the window opens (`HeaderView.swift:69-71`).
- **Auto-hide timer**: if `auto_hide_enabled == "true"`, a one-shot timer of `auto_hide_timeout` seconds (default **5**, `Constants.defaultAutoHideTimeout`, `Constants.swift:30`) hides the window via `toggleWindow()`. Reset on **every keyDown** (`AppViewModel.swift:337-355, 360`).

### 1.9 Settings (every key)

Storage: SQLite `settings` table (key TEXT PRIMARY KEY, value TEXT) unless noted.

| Key | Type (stored) | Default | Effect | Refs |
|---|---|---|---|---|
| `mouse_edge_enabled` | `"true"`/`"false"` | `'true'` (seeded at DB init) | Enables right-edge peek; applied live on toggle, read at boot (`!= "false"` → enabled) | `DatabaseSchema.swift:35-37`, `SettingsUseCase.swift:20-26`, `AppDelegate.swift:40-41`, `SettingsView.swift:53-58` |
| `auto_hide_enabled` | `"true"`/`"false"` | unset (treated `false`) | Enables inactivity auto-hide timer; re-read at every window show | `AppViewModel.swift:350-355`, `SettingsView.swift:60-65` |
| `auto_hide_timeout` | int as string | `5` (constant fallback) | Seconds of inactivity before hide; UI options **3, 5, 10, 30, 60** | `Constants.swift:30`, `SettingsView.swift:15, 67-95`, `AppViewModel.swift:340` |
| `shortcut` | shortcut string | `"CommandOrControl+Shift+V"` | Global toggle hotkey; read once at launch; recorder UI non-functional | `Constants.swift:29`, `AppDelegate.swift:141-148`, `SettingsView.swift:146-147` |
| `auto_start` | `"true"`/`"false"` | set to `"true"` on first run | Mirrors login-item registration (source of truth is `SMAppService.status`) | `AppDelegate.swift:35-37`, `SettingsUseCase.swift:28-39` |
| `windowHeight` (**UserDefaults**, not DB) | Double | unset → 800 | Initial panel height | `MainPanel.swift:8-9, 43-45` |
| Sparkle auto-check (**Sparkle/UserDefaults**) | Bool | Sparkle default (true after first consent) | `updater.automaticallyChecksForUpdates`, toggled from Settings | `UpdateService.swift:27-30`, `SettingsView.swift:101-106` |

### 1.10 Auto-Start

File: `Services/AutoStartService.swift`

- Mechanism: `SMAppService.mainApp.register()` / `.unregister()` (macOS 13+ login item API); `isEnabled` = `status == .enabled` (`AutoStartService.swift:5-22`).
- **Enabled automatically on first run** (when the `auto_start` setting key does not exist yet) (`AppDelegate.swift:34-37`).
- Settings toggle "Launch at Login" calls `setAutoStart(enabled:)` which registers/unregisters and persists the key (`SettingsUseCase.swift:28-35`; `SettingsView.swift:46-51`).

### 1.11 Auto-Update

Files: `Services/UpdateService.swift`, `Resources/Info.plist:21-24`

- Mechanism: **Sparkle 2** (`SPUStandardUpdaterController`, created with `startingUpdater: false`, started explicitly after app launch — `UpdateService.swift:7-21`, `AppDelegate.swift:66`).
- Feed URL: `https://raw.githubusercontent.com/newfull5/PasteSheets/main/appcast.xml` (`SUFeedURL`, `Info.plist:21-22`).
- EdDSA public key: `BKWpRQTjKQV/3QGSqPce778hpmXCicygJi4D3WbqH3M=` (`SUPublicEDKey`, `Info.plist:23-24`).
- When checked: Sparkle's automatic background schedule (default cadence; no custom interval set) when "Automatic Updates" is on, plus a manual **"Check Now"** button in Settings (`checkForUpdates(nil)`, `UpdateService.swift:23-25`; `SettingsView.swift:108-127`).

### 1.12 Menu Bar / Tray

File: `App/AppDelegate.swift:91-137`

- `NSStatusItem` of `squareLength`. Icon: asset named **"TrayIcon"** rendered as a template image; fallback text title `"PS"` if the asset is missing (`AppDelegate.swift:92-101`).
- Button receives both `.leftMouseUp` and `.rightMouseUp` (`AppDelegate.swift:112-113`); no persistent menu attached.
- **Left click**: `previousAppService.saveCurrentApp()` then `vm.toggleWindow()` (`AppDelegate.swift:125-128`).
- **Right click**: builds an ad-hoc menu and pops it: items `"Show App"` (→ `toggleWindow()`, note: without saving previous app) — separator — `"Quit PasteSheet"` (key equivalent `q`, → `NSApp.terminate`) (`AppDelegate.swift:117-124, 131-137`).

### 1.13 Keyboard Handling (complete map)

Architecture: `MainPanel.sendEvent` intercepts every `keyDown`; if `AppViewModel.handleKeyDown(event:)` returns `true` the event is consumed, otherwise it falls through to SwiftUI (text fields, buttons) (`MainPanel.swift:32-41`). Both layers write debug lines to stderr (`MainPanel.swift:34-35`, `AppViewModel.swift:365-366`).

Definitions used below (`AppViewModel.swift:359-366`):
- `isInput` = first responder is an `NSTextView` or `NSTextField` (any focused text field/editor).
- Every keyDown first resets the auto-hide timer (`AppViewModel.swift:360`).
- `listCount` = search: `dirs + items`; directory view: `dirs + 1` (New Folder row); item view: `items + 1` (New Item row) (`AppViewModel.swift:91-99`).

**Escape (keyCode 53)** — priority chain, first match wins (`AppViewModel.swift:369-377`):
1. Confirm modal open → close modal.
2. Detail modal open → close detail.
3. Inline edit active → cancel edit.
4. Settings view → back to directory view.
5. Search query non-empty → clear search.
6. Otherwise → hide window (`toggleWindow`).

**While confirm modal or detail modal is open** (`AppViewModel.swift:379-380`): every key except Escape returns `false` → falls through to SwiftUI. Consequences: typing works in the rename modal's text field, but **Enter does not confirm** (modal buttons are mouse-only); Esc cancels/closes.

**Cmd+Enter (keyCode 36 + ⌘) while inline-editing with a text input focused** → `saveEdit()` (`AppViewModel.swift:383-386`).

**Arrow Down (125)** — always (even while search field focused): `selectedIndex = (selectedIndex + 1) % max(listCount, 1)` (wraps), `buttonFocusIndex = 0` (`AppViewModel.swift:390-393`).

**Arrow Up (126)** — always: `selectedIndex = (selectedIndex − 1 + count) % count` (wraps), `buttonFocusIndex = 0` (`AppViewModel.swift:394-397`).

**Arrow Right (124)** (`AppViewModel.swift:398-409`):
- Search active → `false` (caret moves inside the search field; button focus is impossible in search mode).
- Directory view, a real directory selected (`selectedIndex < dirs.count`) → open that directory.
- Item view → `buttonFocusIndex += 1` if `< 2` (cycles focus Paste→Edit→Delete; max 2).
- Otherwise unhandled.

**Arrow Left (123)** (`AppViewModel.swift:410-422`):
- Search active → `false`.
- Item view: if `buttonFocusIndex > 0` → decrement; else → back to directory view.
- Settings view → back to directory view.

**Enter (36)** when not (editing && input focused) (`AppViewModel.swift:427-443`):
- Search active → `executeSearchAction()`: selected entry is a folder → open it; an item → run action per `buttonFocusIndex` (always 0 in search ⇒ always **Paste**) (`AppViewModel.swift:489-500`).
- Directory view → open selected directory if a real one; **Enter on the "New Folder" row is consumed but does nothing** (inline creation is mouse-only) (`AppViewModel.swift:432-438`).
- Item view → `executeItemAction()`: on selected item run `buttonFocusIndex` action — 0 = Paste, 1 = Edit (start inline edit), 2 = Delete (opens confirm modal) (`AppViewModel.swift:502-516`). Enter on the "New Item" row does nothing.

**Space (49)**, only when: no input focused, item view, no search → open **Detail modal** for the selected item (`AppViewModel.swift:446-452`). (When the search field is focused, space types into the query.)

**Printable character (single letter or number, no ⌘/⌃/⌥, no input focused)** → append to `searchQuery` and focus the search field (`AppViewModel.swift:454-463`). Punctuation does not auto-trigger search.

**Cmd+Backspace (51 + ⌘, no input focused)** (`AppViewModel.swift:466-484`):
- Search active: selected folder → delete-folder modal; selected item → delete-item modal.
- Directory view: delete-folder modal for selection (attempting it on "Clipboard" opens the modal but the actual delete throws and is logged as a no-op).
- Item view: delete-item modal for selection.

**Back navigation memory**: returning to the directory view re-selects the directory you were just in (`showDirectoryView`, `AppViewModel.swift:103-113`).

**Settings view**: only Esc / ← (back) and the global keys above; all controls are mouse-driven. Tab is not specially handled anywhere.

### 1.14 Modals

**Confirm modal** (`Presentation/Views/ConfirmModalView.swift`, state `AppViewModel.modalConfig`):
- Triggers/content (see §1.2/§1.3): Delete Item, Delete Folder (danger, red confirm), Rename Folder (with text input prefilled with old name, accent confirm).
- Buttons: Cancel (closes, no action) and Confirm (runs `onConfirm(inputValue?)` then closes) (`ConfirmModalView.swift:44-67`).
- Backdrop tap dismisses (`ConfirmModalView.swift:19-21`). Keys: Esc closes; everything else falls through (typing edits the input; Enter does nothing).

**Detail modal** (`Presentation/Views/DetailModalView.swift`, state `AppViewModel.detailItem`):
- Trigger: **Space** on a selected item in the item view (no-search) (`AppViewModel.swift:446-452`).
- Content: header `"Detail View"` + **Copy** button (writes item content to the clipboard via `NSPasteboard`, `DetailModalView.swift:24-27`) + **Close** button; scrollable monospaced full content with text selection enabled.
- Keys: Esc closes; backdrop tap closes.

### 1.15 All Constants (`App/Constants.swift:5-31`)

| Constant | Value |
|---|---|
| `accentColor` | RGB(220, 220, 87) = **#DCDC57**, alpha 1.0 (line 7) |
| `subTextColor` | **#68748D** (line 8) |
| `bgContainer` | RGB(18,18,18) = **#121212 @ alpha 0.98** (line 9) |
| `modalDangerColor` | **#EF4444** (tailwind red-500) (line 11) |
| `detailModalBg` | **#1E1E1E** (line 12) |
| `detailContentBg` | **#1A1A1A** (line 13) |
| `dangerColor` | **#FF4444** (line 14) |
| `memoColor` | **#E2E2B6** (line 15) |
| `clipboardPollingInterval` | **0.1 s** (line 16) |
| `mouseEdgePollingInterval` | **0.1 s** (line 17) |
| `mouseEdgeThreshold` | **2.0 pt** (line 18) |
| `windowWidth` | **380.0 pt** (line 19) |
| `windowMinHeight` | **300.0 pt** (line 20) |
| `windowMaxHeight` | **1400.0 pt** (line 21) |
| `windowHideAnimationDelay` | **0.35 s** (line 22) |
| `pasteRestoreDelay1` | **0.08 s** (line 23) |
| `pasteRestoreDelay2` | **0.05 s** (line 24) |
| `pasteToggleDelay` | **0.05 s** (line 25) |
| `mouseEdgeAutoHideDelay` | **0.15 s** (line 26) |
| `maxItemsPerDirectory` | **30** (line 27) |
| `defaultDirectory` | `"Clipboard"` (line 28) |
| `defaultShortcut` | `"CommandOrControl+Shift+V"` (line 29) |
| `defaultAutoHideTimeout` | **5** (seconds) (line 30) |

---

## 2. Design

Theme: fixed dark theme. **No light-mode handling anywhere** — every color is hardcoded; system appearance is ignored. No SF Symbols are used; icon glyphs are literal text characters: `◀` (back), `⚙` (settings), `＋` (new), `|` (blinking cursor). The tray uses the `TrayIcon` asset (template/monochrome).

Color tokens (see §1.15): accent `#DCDC57`, sub-text `#68748D`, container bg `rgba(18,18,18,0.98)`, memo `#E2E2B6`, danger `#FF4444`, modal-danger `#EF4444`, detail modal `#1E1E1E`, detail content `#1A1A1A`.

### 2.1 Window chrome (`ContentView.swift:6-62`, `MainPanel.swift`)

- 380 pt wide; transparent NSPanel with system shadow (`hasShadow = true`).
- Content background: rounded rectangle **corner radius 16**, fill `rgba(18,18,18,0.98)`, 1 pt `strokeBorder` of `white @ 0.10`; content clipped to the same radius (`ContentView.swift:53-61`).
- Layout: VStack(spacing 0): Header (padding: horizontal 16, top 16, bottom 12) → `Divider().opacity(0.1)` → content area (fills) → bottom padding 12 (`ContentView.swift:8-32`).
- Resize handle overlay pinned to bottom: invisible 12 pt-high strip containing a centered capsule **32×3**, `white @ 0.10` (dragging: `0.30`), cursor `resizeUpDown` (`ContentView.swift:65-104`).

### 2.2 HeaderView (`Presentation/Components/HeaderView.swift`)

- HStack spacing 8.
- Back button (item/settings views, no search): text `◀`, 16 pt, accent; `IconButtonStyle` = padding 6, pressed background `white @ 0.10` radius 8 (`HeaderView.swift:29-36, 94-105`).
- Title: `"PasteSheet"` (directory view) / current directory name (item view) / `"Settings"` / `"Search results"` (query non-empty) (`HeaderView.swift:14-21`). Font: system **22 medium** at root, **18 medium** when back button shown; letter tracking 0.66 / 0.54 (≈0.03 em); color accent; lineLimit 1 (`HeaderView.swift:40-44`).
- Blinking cursor: literal `|` in same font/color, toggling opacity every **0.5 s** (`HeaderView.swift:45-53`).
- Search field: plain `TextField` placeholder `"Search Anything..."`, same font as title, accent color, overlaid on the title; title visible when query empty, field visible when non-empty (`HeaderView.swift:38-78`).
- Settings button (hidden on settings view): text `⚙`, 20 pt, `accent @ 0.7`, IconButtonStyle (`HeaderView.swift:82-89`).

### 2.3 DirectoryListView (`Presentation/Views/DirectoryListView.swift`)

- `ScrollView` → VStack spacing **4**, padding horizontal 16 / vertical 4.
- Selection auto-scrolls to center with `easeInOut(0.15)` (`DirectoryListView.swift:34-38`).
- Context menu on rows (non-Clipboard only): "Rename", "Delete" (`DirectoryListView.swift:19-24`).
- **New Folder row** (`DirectoryListView.swift:42-79`): idle = `＋` (18 bold, accent) + `"New Folder"` (14, subText); padding h12 v12; selected background accent @ 0.08 radius 6; **dashed border**: radius 6, `white @ 0.05`, lineWidth 1, dash `[5]`. Click switches to inline `TextField` placeholder `"Folder Name..."` (plain, 14, white); commit (Return inside field) creates the trimmed name; Esc (`onExitCommand`) cancels.

### 2.4 DirectoryRow (`Presentation/Components/DirectoryRow.swift`)

- HStack spacing 0; row padding horizontal 12 / vertical 12.
- Accent bar: rounded rect radius 2, **4 × 18 pt**; selected = accent + glow `shadow(color: accent, radius: 4)`; unselected = `subText @ 0.4`; trailing padding 12 (`DirectoryRow.swift:13-17`).
- Name: 15 pt, white, lineLimit 1.
- Count badge: 12 pt, subText, padding h8 v2, background `white @ 0.08`, corner radius 10 (`DirectoryRow.swift:26-32`).
- Selected row background: accent @ **0.10**, radius 6 (`DirectoryRow.swift:36-39`). Click opens the folder.

### 2.5 ItemListView (`Presentation/Views/ItemListView.swift`)

- `ScrollView` → `LazyVStack` spacing **4**, padding horizontal 16 / vertical 4; auto-scroll to selection `easeInOut(0.15)` center anchor.
- Click on a row selects it (`onTapGesture`, `ItemListView.swift:28`).
- Empty state: `"No items found in this folder"`, 14 pt, `white @ 0.4`, top padding 40 (`ItemListView.swift:34-40`).
- **New Item row** (`ItemListView.swift:53-111`): idle = `＋` (18 bold accent) + `"New Item"` (14, accent @ 0.8); same padding/selected-bg/dashed-border treatment as New Folder. Click expands creator:
  - Memo `TextField` placeholder `"Memo (Optional)..."`: 13 medium, accent, padding 8, bg accent @ 0.05, radius 4.
  - Content `TextEditor`: 14 pt white, minHeight **80**, padding 8, bg `white @ 0.03`, radius 6, border accent @ 0.2.
  - `Save` (active-style ActionButton; trims content, requires non-empty) and `Cancel`.

### 2.6 HistoryItemRow (`Presentation/Components/HistoryItemRow.swift`)

- HStack(top-aligned); row padding horizontal **14** / vertical 12; selected background accent @ **0.08** radius 6.
- Accent bar: width 4, radius 2; selected = full row height + glow (shadow radius 4, accent); unselected = maxHeight **16**, `subText @ 0.4`; trailing padding 12 (`HistoryItemRow.swift:42-48`).
- Inner VStack spacing 4.
- Memo line (if present): 13 medium, color `#E2E2B6`, lineLimit 1 (`HistoryItemRow.swift:71-76`).
- Folder label (search results only, `showFolderLabel`): directory name, 10 pt, `white @ 0.4`, padding h6 v1, bg `white @ 0.08`, radius 4 (`HistoryItemRow.swift:78-86`).
- Content: 14 pt; selected → white, lineLimit **15**; unselected → `white @ 0.7`, lineLimit **1**; tail truncation (`HistoryItemRow.swift:90-95`).
- Selected extras: timestamp 11 pt **monospaced**, `subText @ 0.6`, top padding 8 — formatted by attempting ISO8601-with-fractional-seconds parse → medium date / short time; on parse failure (typical for SQLite `YYYY-MM-DD HH:MM:SS`) the **raw string is shown** (`HistoryItemRow.swift:97-102, 140-150`). Action row: spacing 8, top padding 8: `Paste`, `Edit`, `Delete` (`HistoryItemRow.swift:104-109`).
- **ActionButton** (`HistoryItemRow.swift:153-195`): label 11 pt semibold, padding h10 v4, radius 4, 1 pt border.
  - Active normal: black text on accent, no border.
  - Active danger: white text on `#FF4444`, border `#FF4444`.
  - Inactive: subText text on `white @ 0.05`, border `white @ 0.1`.
- **Inline edit mode** (`HistoryItemRow.swift:113-137`): memo `TextField` placeholder `"Memo"` (13 semibold, accent, padding 8, bg accent @ 0.05, radius 4, border accent @ 0.2); content `TextEditor` (14 white, minHeight **120**, padding 8, bg `white @ 0.03`, radius 6, border accent @ 0.2); `Save` (active) / `Cancel` buttons. Cmd+Enter saves (§1.13).

### 2.7 SearchResultView (`Presentation/Views/SearchResultView.swift`)

- `ScrollView` → `LazyVStack(alignment: .leading, spacing: 4)`, padding h16 v4; auto-scroll like other lists.
- Section headers `"Folders"` / `"Items"`: 11 pt bold, uppercase, `white @ 0.4`, tracking 1, padding leading 8 / top 12 / bottom 4 (`SearchResultView.swift:67-76`).
- Folders rendered as `DirectoryRow`; items as `HistoryItemRow` with `showFolderLabel: true`; selection index is global (folders first) (`SearchResultView.swift:13-46`).
- Empty: `"No matches found for your search."`, 14 pt, `white @ 0.4`, top padding 60 (`SearchResultView.swift:48-54`).

### 2.8 SettingsView (`Presentation/Views/SettingsView.swift`)

- `ScrollView` → VStack(alignment leading, spacing **24**), padding 16.
- Group header: 13 semibold uppercase, subText, tracking 0.5, leading padding 4; group inner spacing 12 (`SettingsView.swift:161-171`).
- Card style (all rows): padding 12, bg `white @ 0.03`, corner radius 12.
- **Shortcut** group: row "Toggle Window" (14 medium white) + shortcut button: displays formatted shortcut (`CommandOrControl→⌘`, `Shift→⇧`, `Alt→⌥`, `Control→⌃`, `+→space`, e.g. `⌘ ⇧ V`), 13 semibold, padding h14 v6, bg `white @ 0.08`, radius 8; recording state: bg `rgb(99,102,241) @ 0.25`, text `rgb(165,180,252)`, label `"Press keys..."` (visual only) (`SettingsView.swift:21-41, 153-159`).
- **General** group: ToggleRows —
  - "Launch at Login" / "Automatically start PasteSheets when you log in."
  - "Mouse Edge Detection" / "Slide into the screen when the mouse hits the right edge."
  - "Auto-hide" / "Automatically hide the window after a period of inactivity."
  - When Auto-hide is on, a "Hide after" row appears: label 14 subText; segmented buttons `3s 5s 10s 30s 60s` — 13 medium, padding h10 v4, selected = white text on `white @ 0.15` radius 7, unselected = subText on clear; container padding 3, bg `white @ 0.05`, radius 10 (`SettingsView.swift:44-95`).
- **Updates** group: ToggleRow "Automatic Updates" / "Automatically check for updates in the background."; row "Check for Updates" with button `"Check Now"` (13 semibold, padding h14 v6, bg `white @ 0.08`, radius 8) (`SettingsView.swift:99-127`).
- **Information** group: infoRows `Version` → `CFBundleShortVersionString` (0.4.1) and `Developer` → `newfull5`; label 14 subText, value 14 medium white (`SettingsView.swift:129-133, 173-182`).

### 2.9 ToggleRow (`Presentation/Components/ToggleRow.swift`)

- HStack: left VStack(spacing 4): label 15 medium white; description 12 subText. Right: switch-style Toggle tinted **accent**. Padding 12, bg `white @ 0.03`, radius 12.

### 2.10 DetailModalView (`Presentation/Views/DetailModalView.swift`)

- Backdrop: `black @ 0.6`, tap to close.
- Panel: **90% of window width × 80% of window height**; bg `#1E1E1E`, radius 12, border `white @ 0.1`, clipped (`DetailModalView.swift:61-67`).
- Header (padding 16, bg `white @ 0.05`): title `"Detail View"` 16 bold white; `Copy` button — black on accent, bold, padding h12 v6, radius 6; `Close` button — white on `white @ 0.1`, padding h12 v6, radius 6. Divider tinted `white @ 0.1` (`DetailModalView.swift:18-47`).
- Body: `ScrollView` with content text 14 pt **monospaced**, `white @ 0.8`, lineSpacing 4, padding 24, `textSelection enabled`, background `#1A1A1A` (`DetailModalView.swift:50-59`).
- Appear animation: `easeInOut(0.2)`, scale 0.95→1, opacity 0→1 (`DetailModalView.swift:68-73`).

### 2.11 ConfirmModalView (`Presentation/Views/ConfirmModalView.swift`)

- Backdrop: `black @ 0.6`, tap to dismiss.
- Panel: maxWidth **340**, padding 24, VStack(leading, spacing 16); bg `rgba(18,18,18,0.98)`, radius **16**, border `white @ 0.1` (`ConfirmModalView.swift:23, 69-75`).
- Title: 18 bold, accent. Message: 14 pt, `white @ 0.9`, lineSpacing 4.
- Optional input (rename): plain TextField, 14 white, padding 8, bg `black @ 0.3`, radius 8, border `white @ 0.1` (`ConfirmModalView.swift:33-42`).
- Buttons right-aligned: Cancel — white text, padding h16 v8, bg `white @ 0.05`, radius 8. Confirm — bold; danger: white on `#EF4444`; normal: black on accent; padding h16 v8, radius 8, drop shadow `(confirm color) @ 0.3, radius 6, y 4` (`ConfirmModalView.swift:44-67`).
- Appear animation: `easeInOut(0.2)`, scale 0.95→1, opacity 0→1.

### 2.12 Animations / transitions summary

| Animation | Spec | Ref |
|---|---|---|
| Window hide | alpha 1→0 over 0.35 s, then orderOut | `AppViewModel.swift:288-295` |
| Window show | instant (no animation) | `AppViewModel.swift:296-307` |
| Edge-peek hide | instant orderOut after 0.15 s delay | `AppViewModel.swift:324-333` |
| Modal appear (both) | easeInOut 0.2 s, scale 0.95→1 + fade in | `ConfirmModalView.swift:76-79`, `DetailModalView.swift:68-73` |
| List scroll-to-selection | easeInOut 0.15 s, anchor center | `DirectoryListView.swift:34-38`, `ItemListView.swift:45-49`, `SearchResultView.swift:59-63` |
| Header cursor blink | opacity toggle every 0.5 s | `HeaderView.swift:48-53` |
| Resize handle | capsule opacity 0.1↔0.3 while dragging | `ContentView.swift:76-78` |

---

## 3. Data

### 3.1 Database

- Engine: SQLite (raw `sqlite3` C API). Singleton connection with a serial `DispatchQueue` (`com.pastesheets.db`) for thread safety (`Data/Database/DatabaseManager.swift:4-10`).
- **File location**: `<Application Support>/paste_sheets.db` — i.e. `~/Library/Application Support/paste_sheets.db` (app is not sandboxed; entitlements file is empty) (`DatabaseManager.swift:12-15`; `Resources/PasteSheets.entitlements`).
- Initialization order (`DatabaseManager.swift:17-32`): create 3 tables → seed default directory → seed `mouse_edge_enabled` → migration (add `memo` column if missing, via `PRAGMA table_info`) → orphan-directory sync.

### 3.2 Schema (`Data/Database/DatabaseSchema.swift:5-46`, verbatim)

```sql
CREATE TABLE IF NOT EXISTS directories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS paste_sheets (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    content     TEXT NOT NULL,
    directory   TEXT NOT NULL,
    memo        TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (directory) REFERENCES directories(name)
);

CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Seeds / maintenance
INSERT OR IGNORE INTO directories (name) VALUES ('Clipboard');
INSERT OR IGNORE INTO settings (key, value) VALUES ('mouse_edge_enabled', 'true');
ALTER TABLE paste_sheets ADD COLUMN memo TEXT;            -- migration, only if missing
INSERT OR IGNORE INTO directories (name)                  -- orphan sync at startup
SELECT DISTINCT directory FROM paste_sheets;
```

- `created_at` values are SQLite `CURRENT_TIMESTAMP` strings (`YYYY-MM-DD HH:MM:SS`, UTC).
- Items reference directories **by name** (not id); rename rewrites both tables inside a transaction with FK checks temporarily off (`DirectoryDataSource.swift:50-61`).

### 3.3 Settings keys & defaults (recap)

| Store | Key | Default |
|---|---|---|
| SQLite `settings` | `mouse_edge_enabled` | `'true'` (seeded) |
| SQLite `settings` | `auto_hide_enabled` | unset → off |
| SQLite `settings` | `auto_hide_timeout` | unset → `5` |
| SQLite `settings` | `shortcut` | unset → `CommandOrControl+Shift+V` |
| SQLite `settings` | `auto_start` | `'true'` written on first run |
| UserDefaults | `windowHeight` | unset → 800 |
| Sparkle (UserDefaults) | automatic update checks | Sparkle default |

### 3.4 DTO / Entity shapes

- `PasteItemDTO` / `PasteItem`: `id: Int64`, `content: String`, `directory: String`, `createdAt: String`, `memo: String?` (`Data/DTOs/PasteItemDTO.swift`, `Domain/Entities/PasteItem.swift`).
- `DirectoryInfoDTO` / `DirectoryInfo`: `name: String`, `count: Int64`; entity `id` = `name` (`Data/DTOs/DirectoryInfoDTO.swift`, `Domain/Entities/DirectoryInfo.swift`).

### 3.5 Porting caveats (behaviors a pixel-perfect port must reproduce)

1. Show always repositions to right edge at full visible height — user resize does not survive a hide/show cycle (§1.8).
2. Dedup/edit both bump `created_at`, reordering lists (§1.1, §1.3).
3. The 30-item cap applies only to the "Clipboard" folder on capture (§1.1).
4. Edge-peek windows auto-dismiss on mouse-leave; hotkey windows do not (§1.7).
5. Search mode locks `buttonFocusIndex` at 0 → Enter on a searched item always pastes (§1.13).
6. Enter cannot activate "New Folder"/"New Item" rows or modal buttons — mouse only (§1.13, §1.14).
7. Shortcut recorder UI is cosmetic; hotkey is fixed at the stored/default value until restart (§1.6).
8. Timestamp display falls back to the raw DB string because the ISO8601 parser does not match SQLite's format (§2.6).
9. Clipboard is not restored after paste; pasted content remains the active clipboard entry (§1.5).
