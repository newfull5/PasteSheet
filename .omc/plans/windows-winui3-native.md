# Windows Native App — C# + WinUI 3 Implementation Plan

> **Date**: 2026-06-13
> **Branch**: `feat/windows-winui3` from `develop`
> **Target**: Full feature & design parity with macOS v0.4.1
> **Replaces**: Tauri-based `apps/windows/` (PRs #39-#43 to be closed)

---

## Context

PasteSheets is a clipboard manager with a macOS native app (Swift/AppKit, v0.4.1) that is the source of truth. The existing Windows port uses Tauri (Rust + Svelte) but has critical gaps (no focus restore, no edge peek, no auto-update, design mismatches). This plan creates a clean C# + WinUI 3 app at `apps/windows/` sharing the same SQLite schema and business rules.

**Reference docs:**
- `.omc/research/macos-spec.md` — definitive behavioral/design spec (440 lines)
- `docs/windows-parity-gap-analysis.md` — gap analysis vs Tauri app
- `apps/macos/` — Swift source (architecture reference)

---

## Work Objectives

1. Ship a Windows-native clipboard manager with identical UX to macOS v0.4.1
2. Share the same SQLite DB schema (`paste_sheets.db`) and business rules
3. Use Windows-native APIs for all platform interactions
4. Match macOS design pixel-for-pixel (colors, spacing, typography, animations)

---

## Guardrails

### Must Have
- Same 3-table SQLite schema (directories, paste_sheets, settings)
- All 13 features from macOS spec (clipboard monitor, folders, items, search, paste flow, hotkey, edge peek, window management, settings, auto-start, auto-update, tray, keyboard handling)
- All design tokens from Constants.swift (colors, sizes, timings)
- MSIX packaging for Windows 10/11

### Must NOT Have
- No light theme (macOS has none)
- No Storage settings group (macOS uses fixed 30-item cap)
- No hardcoded secrets or environment-specific values
- No features beyond macOS v0.4.1 parity (except D-1/D-2 from gap analysis: working shortcut recorder, Enter-confirm in modals — keep these)

---

## Architecture

```
apps/windows/PasteSheets.sln
├── PasteSheets/                        (WinUI 3 app project)
│   ├── App.xaml(.cs)                   (lifecycle, tray, single-instance)
│   ├── Data/
│   │   ├── Database/
│   │   │   ├── DatabaseManager.cs      (SQLite connection, serial queue)
│   │   │   └── DatabaseSchema.cs       (CREATE/seed/migrate/orphan-sync)
│   │   └── DataSources/
│   │       ├── PasteItemDataSource.cs  (CRUD, dedup, cleanup)
│   │       ├── DirectoryDataSource.cs  (CRUD, rename-transaction)
│   │       └── SettingsDataSource.cs   (key-value get/set)
│   ├── Domain/
│   │   ├── Entities/                   (PasteItem, DirectoryInfo)
│   │   └── UseCases/
│   │       ├── ClipboardMonitorUseCase.cs
│   │       ├── ManageDirectoriesUseCase.cs
│   │       ├── SearchUseCase.cs
│   │       ├── PasteTextUseCase.cs
│   │       └── SettingsUseCase.cs
│   ├── Services/
│   │   ├── ClipboardService.cs         (Win32 clipboard polling)
│   │   ├── HotkeyService.cs            (RegisterHotKey)
│   │   ├── PreviousAppService.cs       (GetForegroundWindow/SetForegroundWindow)
│   │   ├── KeySimulationService.cs     (SendInput Ctrl+V)
│   │   ├── MouseEdgeService.cs         (GetCursorPos polling)
│   │   ├── WindowPositionService.cs    (monitor detection, right-edge snap)
│   │   ├── AutoStartService.cs         (Registry Run key)
│   │   └── UpdateService.cs            (WinSparkle or custom GitHub updater)
│   ├── Presentation/
│   │   ├── ViewModels/
│   │   │   └── AppViewModel.cs         (all state, keyboard handler, commands)
│   │   ├── Views/
│   │   │   ├── MainWindow.xaml(.cs)    (borderless, floating, shadow)
│   │   │   ├── ContentView.xaml        (layout: header + divider + content + resize handle)
│   │   │   ├── DirectoryListView.xaml
│   │   │   ├── ItemListView.xaml
│   │   │   ├── SearchResultView.xaml
│   │   │   ├── SettingsView.xaml
│   │   │   ├── ConfirmModalView.xaml
│   │   │   └── DetailModalView.xaml
│   │   └── Components/
│   │       ├── HeaderView.xaml
│   │       ├── DirectoryRow.xaml
│   │       ├── HistoryItemRow.xaml
│   │       ├── ToggleRow.xaml
│   │       └── ActionButton.xaml
│   ├── Helpers/
│   │   ├── Constants.cs                (all values from macOS Constants.swift)
│   │   └── Win32Interop.cs             (P/Invoke declarations)
│   └── Assets/                         (tray icon, app icon)
└── PasteSheets.Package/               (MSIX packaging project)
    └── Package.appxmanifest
```

**NuGet packages:**
- `Microsoft.WindowsAppSDK` (WinUI 3)
- `Microsoft.Windows.CsWinRT`
- `Microsoft.Xaml.Behaviors.WinUI.Managed`
- `sqlite-net-pcl` or `Microsoft.Data.Sqlite`
- `CommunityToolkit.Mvvm` (ObservableObject, RelayCommand)
- `H.NotifyIcon.WinUI` (system tray)
- `WinSparkle` (auto-update) or custom GitHub Releases checker

---

## Task Flow

### Milestone 1: Project Scaffold + Data Layer
**PR: `feat/windows-winui3-scaffold`**

**1.1 Create solution structure**
- New `apps/windows/PasteSheets.sln` with WinUI 3 Blank App template
- Configure for .NET 8 + Windows App SDK 1.5+
- Set up MSIX packaging project with app identity
- Add NuGet packages listed above
- Create folder structure matching architecture diagram
- Add `Constants.cs` with ALL values from macOS `Constants.swift` (see spec section 1.15)

**1.2 Implement SQLite data layer**
- `DatabaseManager.cs`: singleton connection, serial access (SemaphoreSlim), file at `%LOCALAPPDATA%/paste_sheets.db`
- `DatabaseSchema.cs`: exact same CREATE TABLE statements, seeds, memo migration, orphan sync
- `PasteItemDataSource.cs`: all queries matching macOS SQL exactly (findByContent, insert, update with created_at bump, cleanup oldest beyond 30, delete)
- `DirectoryDataSource.cs`: list with Clipboard-first ordering + count, create with trim+empty check, rename transaction with FK off, delete with cascade
- `SettingsDataSource.cs`: get/set key-value pairs
- Entity classes: `PasteItem` (id, content, directory, createdAt, memo), `DirectoryInfo` (name, count)

**Acceptance criteria:**
- [ ] Solution builds on Windows with `dotnet build`
- [ ] DB file created at correct path on first run
- [ ] All 3 tables created with correct schema
- [ ] Default "Clipboard" directory seeded
- [ ] CRUD operations work via unit tests for all DataSources
- [ ] Orphan sync runs at startup

---

### Milestone 2: Domain + Core Services
**PR: `feat/windows-winui3-services`**

**2.1 Domain use cases**
- `ClipboardMonitorUseCase`: poll every 0.1s, text-only, empty filter (trim check, store original), dedup by content+directory, bump created_at on dedup, cleanup to 30 in "Clipboard" only
- `ManageDirectoriesUseCase`: create/rename/delete with all validation rules from macOS
- `SearchUseCase`: case-insensitive substring on directory name, item content, and item memo
- `PasteTextUseCase`: exact sequence — hide window, wait 50ms, write clipboard, restore focus, wait 80ms, restore again, wait 50ms, simulate Ctrl+V
- `SettingsUseCase`: read/write all settings keys, auto-start integration

**2.2 Platform services (Win32 P/Invoke)**
- `ClipboardService`: `AddClipboardFormatListener` / polling timer comparing sequence number (`GetClipboardSequenceNumber`), `OpenClipboard`/`GetClipboardData`/`SetClipboardData`
- `HotkeyService`: `RegisterHotKey` with window message pump; default Ctrl+Shift+V; parse shortcut string same as macOS
- `PreviousAppService`: save `GetForegroundWindow()` HWND at hotkey press and tray click; restore via `SetForegroundWindow` + `AllowSetForegroundWindow`
- `KeySimulationService`: `SendInput` with `INPUT_KEYBOARD` for Ctrl+V keydown/keyup
- `MouseEdgeService`: timer every 0.1s, `GetCursorPos`, detect cursor within 2px of right edge of current monitor; show/hide rules matching macOS (auto-hide only for edge-opened windows)
- `WindowPositionService`: enumerate monitors via `EnumDisplayMonitors` or WinUI `DisplayArea`, find monitor containing cursor, calculate right-edge snap position at full work-area height
- `AutoStartService`: `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` registry key
- `Win32Interop.cs`: all P/Invoke signatures in one file

**Acceptance criteria:**
- [ ] Clipboard monitoring detects text changes within 100ms
- [ ] Dedup correctly bumps existing items (no duplicates in "Clipboard")
- [ ] Global hotkey Ctrl+Shift+V registers and fires
- [ ] Focus correctly returns to previous app after paste sequence
- [ ] Ctrl+V is simulated into the target app
- [ ] Mouse edge detection triggers at right-edge threshold
- [ ] Window snaps to correct monitor's right edge at full work-area height
- [ ] Auto-start registry key created/removed correctly

---

### Milestone 3: Presentation — Window + Navigation
**PR: `feat/windows-winui3-window`**

**3.1 MainWindow (borderless floating panel)**
- Borderless window (`ExtendsContentIntoTitleBar = true`, custom title bar removed)
- Fixed width 380px, height = work area height on show
- `Topmost = true` (floating), no taskbar entry
- System shadow via `DropShadow`
- Background: rounded rect corner radius 16, fill `rgba(18,18,18,0.98)`, 1px stroke `white @ 0.10`
- Show on all virtual desktops (`SetWindowLong` with appropriate styles or WinUI equivalent)
- Show: instant appear, position snap, activate
- Hide: opacity fade 1->0 over 350ms, then hide
- Resize handle: bottom 12px strip with 32x3 capsule, vertical drag only, clamp 300-1400

**3.2 AppViewModel (central state)**
- Observable properties: currentView, selectedIndex, buttonFocusIndex, searchQuery, isWindowVisible, isAutoHideMode, editingItemId, modalConfig, detailItem
- Complete keyboard handler matching macOS keymap exactly (Escape chain, arrows, Enter, Space, Cmd+Backspace, printable char -> search, Cmd+Enter -> save edit)
- Map macOS Cmd to Windows Ctrl throughout
- Auto-hide timer: configurable timeout (3/5/10/30/60s), reset on every keypress

**3.3 Navigation structure**
- Header + Divider + Content area + Resize handle
- Content switches between: DirectoryListView, ItemListView, SearchResultView, SettingsView
- Modal overlay layer for ConfirmModal and DetailModal

**Acceptance criteria:**
- [ ] Window appears borderless at right edge of active monitor
- [ ] Window hides with 350ms fade animation
- [ ] Escape chain works in correct priority order
- [ ] Arrow keys navigate lists with wrapping
- [ ] Enter triggers correct action per context (paste/open folder/search action)
- [ ] Auto-hide timer works with all timeout options
- [ ] Typing a letter/number auto-triggers search

---

### Milestone 4: Presentation — All Views (Design Parity)
**PR: `feat/windows-winui3-views`**

**4.1 HeaderView**
- Back button: `◀` 16pt accent, pressed bg `white @ 0.10` radius 8
- Title: system 22 medium (root) / 18 medium (with back), tracking 0.03em, accent, lineLimit 1
- Blinking cursor: `|` toggling opacity every 0.5s
- Search field overlay: same font, accent, placeholder "Search Anything..."
- Settings button: `⚙` 20pt, accent @ 0.7

**4.2 DirectoryListView + DirectoryRow**
- ScrollView with VStack spacing 4, padding h16 v4
- Auto-scroll to selection with easeInOut 150ms
- Row: accent bar 4x18 (selected: accent+glow, unselected: subText@0.4), name 15pt white, count badge 12pt
- Selected bg: accent @ 0.10, radius 6
- Context menu: Rename, Delete (not on Clipboard)
- New Folder row: dashed border radius 6, `white@0.05`, dash[5], `＋` icon

**4.3 ItemListView + HistoryItemRow**
- LazyVStack spacing 4, auto-scroll
- Row: accent bar (selected: full height+glow, unselected: maxH 16), content 14pt (selected: white lineLimit 15, unselected: white@0.7 lineLimit 1)
- Memo line: 13 medium, `#E2E2B6`
- Selected extras: timestamp 11pt monospaced subText@0.6, action buttons (Paste/Edit/Delete)
- ActionButton styles: active=black-on-accent, danger=white-on-#FF4444, inactive=subText-on-white@0.05
- Inline edit mode: memo field + content TextEditor + Save/Cancel
- New Item row: same dashed border pattern, expands to creator form
- Empty state: "No items found in this folder" 14pt white@0.4

**4.4 SearchResultView**
- Section headers "Folders"/"Items": 11pt bold uppercase white@0.4 tracking 1
- Folders as DirectoryRow, items as HistoryItemRow with folder label badge
- Empty: "No matches found for your search." 14pt white@0.4 padding-top 60

**4.5 SettingsView**
- Groups: Shortcut, General, Updates, Information (match macOS exactly)
- Card style: padding 12, bg white@0.03, radius 12
- Shortcut row: display formatted shortcut (Ctrl->⌃, Shift->⇧ etc), recording state visual
- General toggles: Launch at Login, Mouse Edge Detection, Auto-hide with timeout selector (3/5/10/30/60s segmented)
- Updates: Automatic Updates toggle, Check Now button
- Information: Version (from assembly), Developer "newfull5"

**4.6 Modals**
- ConfirmModal: maxWidth 340, padding 24, bg container, radius 16, border white@0.1; title 18 bold accent; message 14 white@0.9; optional text input; Cancel/Confirm buttons; appear animation scale 0.95->1 + fade 200ms
- DetailModal: 90%x80% of window, bg #1E1E1E, radius 12; header with Copy/Close; scrollable monospaced content on #1A1A1A; same appear animation

**Acceptance criteria:**
- [ ] Every view matches macOS spec pixel-for-pixel (compare screenshots side by side)
- [ ] All color tokens match Constants.swift values exactly
- [ ] All font sizes, weights, spacing, and padding match spec
- [ ] Dashed borders render correctly on New Folder/New Item rows
- [ ] Accent bar glow effect renders on selected rows
- [ ] Both modals animate correctly on appear
- [ ] Settings toggles persist and apply immediately

---

### Milestone 5: App Integration + Packaging
**PR: `feat/windows-winui3-integration`**

**5.1 System tray**
- H.NotifyIcon.WinUI with custom tray icon (template/monochrome)
- Left click: save foreground window, then toggle window
- Right click: context menu with "Show App" and "Quit PasteSheet"

**5.2 App lifecycle**
- Single instance enforcement (mutex or `AppInstance`)
- Startup: init DB, register hotkey, start clipboard monitor, start mouse edge service (if enabled), register tray, set auto-start on first run
- On window show: reload data, clear search, reset selection, restart auto-hide timer
- Window close = hide (not terminate)

**5.3 Auto-update**
- WinSparkle integration or custom GitHub Releases checker
- Appcast/latest.json URL pointing to GitHub Releases
- Settings toggle for automatic checks + manual "Check Now"
- EdDSA signature verification

**5.4 MSIX packaging**
- Package.appxmanifest with correct identity, capabilities
- App icon assets at all required sizes
- Startup task declaration for auto-start (alternative to registry if MSIX)

**Acceptance criteria:**
- [ ] Tray icon appears, left/right click behaviors match macOS
- [ ] Only one instance can run at a time
- [ ] App starts with all services running
- [ ] Window show refreshes all data
- [ ] Auto-update checks work (manual + automatic)
- [ ] MSIX package installs and runs correctly on Windows 10/11
- [ ] No taskbar entry visible during normal operation

---

## PR Breakdown Summary

| PR | Branch | Scope | Est. Complexity |
|----|--------|-------|-----------------|
| 1 | `feat/windows-winui3-scaffold` | Solution, NuGet, Constants, SQLite data layer | MEDIUM |
| 2 | `feat/windows-winui3-services` | Domain use cases + Win32 services | HIGH |
| 3 | `feat/windows-winui3-window` | MainWindow, AppViewModel, keyboard, navigation | HIGH |
| 4 | `feat/windows-winui3-views` | All views pixel-perfect, modals, settings | HIGH |
| 5 | `feat/windows-winui3-integration` | Tray, lifecycle, auto-update, MSIX | MEDIUM |

All PRs target `develop`. English commit messages prefixed with milestone context.

---

## Success Criteria

1. Every feature from macOS spec sections 1.1-1.14 works identically on Windows
2. Every design token from section 2 renders correctly
3. Same SQLite schema and DB file (`paste_sheets.db`) used
4. App runs as a tray-only app with no taskbar entry
5. Global hotkey, edge peek, focus restore, and paste simulation all work natively
6. MSIX package installs cleanly on Windows 10/11
