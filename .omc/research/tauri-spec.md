# Tauri App (v0.2.0) — Complete Feature + Design Specification

Source: `/Users/saechan/RustProjects/PasteSheets/_deprecated/`
Product name: **PasteSheet** (identifier `com.newfull5.pastesheet`), version **0.2.0** (tauri.conf.json:3-5, Cargo.toml:4).
Stack: Tauri 2.9.4 (Rust) + Svelte 5 + Tailwind CSS 4 (beta) + SQLite (rusqlite, bundled).

All file paths below are relative to `_deprecated/`.

---

## 1. Features

### 1.1 Clipboard monitoring

- Mechanism: background OS thread polling the system clipboard via `arboard::Clipboard::get_text()` (src-tauri/src/modules/clipboard.rs:46-57, 58-111). No OS clipboard-change notification API; pure polling.
- Interval: **100 ms** — `const POLLING_INTERVAL: u64 = 100;` (clipboard.rs:16), `thread::sleep(Duration::from_millis(POLLING_INTERVAL))` (clipboard.rs:63).
- Trigger condition: new text differs from `last_content` AND is not whitespace-only (`!current_text.trim().is_empty()`) (clipboard.rs:66). Only **text** is captured (no images/files).
- Dedup: exact content match within the `"Clipboard"` directory only, via `find_by_content(&current_text, "Clipboard")` (clipboard.rs:69; db.rs:186-205). If found, the existing row is **updated** (keeps its memo, `created_at` bumped to `CURRENT_TIMESTAMP` → moves to top) (clipboard.rs:70-82; db.rs:178-185). If not found, inserts a new row (clipboard.rs:83-91).
- Default directory for captures: **"Clipboard"** — `const CLIPBOARD_DEFAULT_DIRECTORY: &str = "Clipboard";` (clipboard.rs:14).
- Max items / cleanup: after each new insert, `cleanup_old_items("Clipboard")` (clipboard.rs:92-94, 17-45). Limit from setting `max_items_per_directory`, default **50** (`DEFAULT_MAX_ITEMS: i64 = 50`, clipboard.rs:15). If `max_items <= 0` → unlimited (clipboard.rs:23-25). Excess rows deleted **oldest first** (`ORDER BY created_at ASC LIMIT excess`) (clipboard.rs:34-42). Cleanup applies only to the directory passed in — in practice only "Clipboard"; manual items in other folders are never auto-pruned.
- On any change (insert or dedup-update), emits Tauri event **`"clipboard-updated"`** (payload `()`) to the frontend (clipboard.rs:100-105). Frontend listens and reloads directories + history (frontend/src/App.svelte:165-168).
- Monitoring starts at app setup: `clipboard::monitor_clipboard(app.handle().clone())` (src-tauri/src/lib.rs:227).

### 1.2 Directory (folder) management

- Operations: list, create, rename, delete (Tauri commands, lib.rs:31-46; db.rs:15-35, 104-149).
- List: `get_directories()` returns `{name, count}` per directory with item counts via `LEFT JOIN`; **ordering: "Clipboard" always first, then by `created_at`** (db.rs:17-23: `ORDER BY CASE WHEN d.name = 'Clipboard' THEN 0 ELSE 1 END, d.created_at`).
- Create: name is trimmed; empty name → error (`rusqlite::Error::InvalidQuery`) (db.rs:104-112). Duplicate names rejected by `UNIQUE` constraint.
- Rename: forbidden if old or new name is `"Clipboard"`, or new name empty after trim (db.rs:113-118). Performed in a transaction with `PRAGMA foreign_keys = OFF`: updates `directories.name` then all `paste_sheets.directory` rows (db.rs:120-139). Renaming a nonexistent dir → `QueryReturnedNoRows` (db.rs:128-130).
- Delete: forbidden for `"Clipboard"` (db.rs:141-144). Deletes all items in the directory then the directory row (db.rs:145-148).
- Default directory: `"Clipboard"` inserted at DB init with `INSERT OR IGNORE` (db.rs:51-54). Also any directories referenced by orphaned items are recreated at init (db.rs:86-90).
- Frontend: directory create via inline input row ("New Folder", DirectoryView.svelte:86-113); rename/delete via right-click context menu (DirectoryView.svelte:49-64, 114-125) or keyboard (Cmd/Ctrl+Backspace = delete). Rename uses input modal; delete uses danger confirm modal (App.svelte:241-274).

### 1.3 Item management

- Save (manual create): "New Item" inline form in ItemView with memo input (optional) + content textarea; saved to the **currently open directory** via `create_history_item` (ItemView.svelte:48-62, 143-208; App.svelte:297-311). Content required (trimmed), memo optional (null if blank).
- Edit: per-item Edit button or keyboard; edit mode replaces the row with memo `Input` + content `textarea` + Save/Cancel buttons (HistoryItem.svelte:63-90). Save calls `update_history_item` with `directory: currentDirId` (App.svelte:282-296). Editing **bumps `created_at` to CURRENT_TIMESTAMP** (db.rs:181), reordering the item to top.
- Delete: per-item Delete button / Cmd+Backspace → danger confirm modal → `delete_history_item` (App.svelte:312-328; db.rs:206-210).
- Move between directories: **no explicit move UI**. (Mechanically possible because `update_content` accepts a directory, and `startEdit` sets `currentDirId = item.directory` (App.svelte:280), but no drag-drop or "move to folder" feature.)
- Ordering: `get_clipboard_history` returns **all items across all directories**, `ORDER BY created_at DESC` (db.rs:158-177). Frontend filters by current directory client-side (App.svelte:102-109). No manual reordering/pinning.
- Item fields: `id, content, directory, created_at, memo` (db.rs:7-14).

### 1.4 Search

- Exists: **yes**, frontend-only (no SQL search). One search input lives in the header, overlaid on the title (Header.svelte:30-35).
- Activation: typing any printable character (key length 1) or Backspace anywhere (when not in an input and no Cmd/Ctrl/Alt modifier) auto-focuses the search input (App.svelte:410-414). Non-empty `searchQuery` switches the main area to SearchView (App.svelte:567-585).
- Scope: global —
  - Folders: directory **name** contains query (App.svelte:99-101).
  - Items: **content OR memo** contains query, across **all** directories (`globalFilteredItems`, App.svelte:110-116).
  - When no query and in items view, items filtered to current directory + content/memo match (App.svelte:102-109).
- Matching: case-insensitive substring (`toLowerCase().includes()`). No fuzzy match, no highlighting.
- Results UI: two sections, "Folders" then "Items" (uppercase 11px headers); items show a folder badge (`showFolderLabel={true}`) (SearchView.svelte:60-122).
- Selection spans both sections as a single index (folders first, then items).

### 1.5 Paste flow

Exact sequence when user pastes an item (Paste button / Enter):

1. Frontend `useItem(item)` (App.svelte:220-230): `invoke("toggle_main_window")` (hides window), then `setTimeout(..., 50)` → `invoke("paste_text", { text: item.content })`.
2. Backend `paste_text` (clipboard.rs:112-142):
   1. Write text to system clipboard with `arboard` (clipboard.rs:113-117).
   2. `restore_prev_app_native()` — refocus the previously active app (clipboard.rs:119).
   3. Sleep **80 ms** (clipboard.rs:120).
   4. macOS only: call `restore_prev_app_native()` **again** + sleep **50 ms** (clipboard.rs:121-125).
   5. Simulate the paste keystroke via **enigo 0.6** (clipboard.rs:126-140):
      - macOS: `Key::Meta` Press → `raw(9, Click)` (keycode 9 = V) → `Key::Meta` Release (clipboard.rs:127-132).
      - Windows: `Key::Control` Press → `raw(86, Click)` (VK 0x56 = 'V') → `Key::Control` Release (clipboard.rs:133-140).
3. Focus handling / previous-app tracking:
   - On hotkey press and at app start, `save_current_app()` records the frontmost app name via `active-win-pos-rs` (`get_active_window().app_name`), skipping `"PasteSheet"` and `"Electron"` (hotkey.rs:32-48; called at lib.rs:131 and hotkey.rs:83).
   - `restore_prev_app_native()` is **macOS-only**: iterates `NSWorkspace.sharedWorkspace.runningApplications`, matches `localizedName`, calls `activateWithOptions(1 << 1)` (= NSApplicationActivateIgnoringOtherApps) (hotkey.rs:49-78). **On Windows the function body is empty (no-op) — focus restore is unimplemented.**

### 1.6 Global hotkey

- Default combo: **`CommandOrControl+Shift+V`** (`DEFAULT_SHORTCUT`, hotkey.rs:10).
- Registration: `tauri-plugin-global-shortcut` 2.x, registered at setup from the `shortcut` DB setting (fallback to default) (hotkey.rs:11-21; plugin init with handler lib.rs:110-114; setup call lib.rs:229).
- Handler: fires only on `ShortcutState::Pressed`; calls `save_current_app()` then `toggle_main_window` (hotkey.rs:79-85).
- Re-binding: `update_shortcut` command → `unregister_all()` → `register(new)` → persist setting `shortcut` (hotkey.rs:22-31; lib.rs:74-77).
- Frontend recorder (SettingsView.svelte:25-64): click the shortcut chip → "Press keys..."; captures keydown requiring ≥1 modifier; ignores bare modifier keys; builds string as `CommandOrControl`(+`Shift`)(+`Alt`)+`KEY` where KEY = `e.code` stripped of `Key`/`Digit` prefix (SettingsView.svelte:38-46). Click elsewhere cancels recording (SettingsView.svelte:97). Display formatting: `CommandOrControl→⌘ Shift→⇧ Alt→⌥ Control→⌃`, `+` → space (SettingsView.svelte:16-23).

### 1.7 Mouse edge peek

- Exists: **yes, macOS only**. Monitor spawned at setup `start_mouse_edge_monitor` (lib.rs:231; window_manager.rs:72-84) — thread only created under `#[cfg(target_os = "macos")]` (window_manager.rs:76-83).
- Edge: **right edge** of the screen the mouse is on (multi-monitor aware via `NSScreen.screens`, window_manager.rs:199-230).
- Behavior (window_manager.rs:130-192):
  - Show: mouse x ≥ `right_edge - 2.0` px (`show_threshold = 2.0`, window_manager.rs:156) and window not visible → position window at `(right_edge - window_width, screen.y)`, set visible + `auto_hide = true`, emit `window-visible:true`, `show()`, `set_focus()` (window_manager.rs:162-176).
  - Hide: mouse x < `right_edge - window_width` (`hide_threshold = window_width`, window_manager.rs:157) and window was shown by edge-peek (`auto_hide == true`) → emit `window-visible:false`, sleep **150 ms** (slide-out animation), `hide()` (window_manager.rs:177-186). Windows shown via hotkey/tray (`auto_hide = false`) are NOT auto-hidden by mouse position.
- Interval: poll every **100 ms**; when the setting is off, sleeps **500 ms** per loop (window_manager.rs:135-138, 190).
- Toggle: setting `mouse_edge_enabled` (default `'true'`, seeded in DB at init db.rs:98-101) drives `MOUSE_EDGE_ENABLED` atomic (window_manager.rs:9, 126-129; applied at startup lib.rs:143-145 and on setting change lib.rs:69-71).
- Windows: `get_mouse_location()` returns `None` (window_manager.rs:239-242) and `get_screen_width()` returns `None` (window_manager.rs:243-246) — **stubs; feature missing on Windows**.

### 1.8 Window

- Config (tauri.conf.json:15-29): label `main` (default), title `"PasteSheet"`, **width 380, height 800**, `resizable: false`, `fullscreen: false`, `decorations: false`, `transparent: true`, `shadow: false`, `alwaysOnTop: true`, `visible: false` (starts hidden), `focus: false`. `macOSPrivateApi: true` (tauri.conf.json:14) enables transparency on macOS.
- Position logic: top-right corner of the active screen — `x = screen.x + screen.width - window_width`, `y = screen.y` (window_manager.rs:56-58 on toggle-show, 103-105 initial). Initial placement happens in `start_mouse_edge_monitor` → `set_window_position` after a 100 ms sleep (window_manager.rs:85-121). macOS uses NSScreen active-screen detection; the generic fallback uses the **first** monitor at logical `(width - 410, 0)` (window_manager.rs:109-119). Note: fallback width constant is **410.0** in Rust (window_manager.rs:55, 102, 114, 154) although the real window is 380 wide.
- Toggle show/hide (`toggle_main_window`, window_manager.rs:18-71):
  - Hide: set state false, emit `window-visible:false` (frontend plays slide-out), background thread sleeps **350 ms** then physically `hide()` if still hidden (window_manager.rs:22-37).
  - Show: (macOS) reposition to active monitor top-right, `show()`, `set_focus()`, then after **20 ms** emit `window-visible:true` (slide-in animation) (window_manager.rs:38-69).
- Resizable: window is `resizable:false`, but **custom height-only resize** exists: bottom drag handle (App.svelte:543-548) → `start_height_resize`/`stop_height_resize` commands; Rust thread polls mouse every **8 ms** and calls `set_size(LogicalSize(380.0, new_height))`, clamped to **min 300 / max 1400** (`RESIZE_WINDOW_WIDTH = 380.0`, `RESIZE_MIN_HEIGHT = 300.0`, `RESIZE_MAX_HEIGHT = 1400.0`, window_manager.rs:248-250, 252-287). macOS Y axis inverted handling (window_manager.rs:275-277). **Body is macOS-only — no-op on Windows.** Final height persisted to `localStorage["windowHeight"]` (App.svelte:341-347) and restored on mount with the same clamps (App.svelte:140-146; `MIN_HEIGHT=300, MAX_HEIGHT=1400, WINDOW_WIDTH=380`, App.svelte:330-332).
- Always-on-top: yes (config). Focus: `set_focus()` called on every show (window_manager.rs:62, 171).
- Close behavior: `CloseRequested` → `hide()` + `prevent_close()`; app stays alive in tray (lib.rs:115-122).
- Dock/taskbar: macOS `ActivationPolicy::Accessory` → **no Dock icon** (lib.rs:132-133). Windows: no `skipTaskbar` set → window **would appear in taskbar** (gap; no Windows equivalent implemented).
- Auto-hide on inactivity (frontend feature, App.svelte:17-46): if setting `auto_hide_enabled`, a timer of `auto_hide_timeout` seconds (default **5**) hides the window via `toggle_main_window`; reset on any keydown (App.svelte:355) and container mousemove (App.svelte:534); cleared when window hides.

### 1.9 Settings

Stored in SQLite `settings` table (key/value TEXT) in the main DB (db.rs:91-97, 211-228). Read/write via `get_setting`/`update_setting` commands (lib.rs:62-73).

| Key | Default | Where defaulted | UI |
|---|---|---|---|
| `mouse_edge_enabled` | `'true'` | seeded at DB init (db.rs:98-101) | Toggle "Mouse Edge Detection — Slide into the screen when the mouse hits the right edge." (SettingsView.svelte:120-127) |
| `auto_hide_enabled` | `false` (absent → false) | frontend (SettingsView.svelte:69-70; App.svelte:151) | Toggle "Auto-hide — Automatically hide the window after a period of inactivity." (SettingsView.svelte:128-134) |
| `auto_hide_timeout` | `5` (seconds) | frontend (SettingsView.svelte:72; App.svelte:152) | Segmented control **3s / 5s / 10s / 30s / 60s**, shown only when auto-hide on (SettingsView.svelte:135-148) |
| `shortcut` | `CommandOrControl+Shift+V` | hotkey.rs:10; SettingsView.svelte:74 | Shortcut recorder chip under "Shortcut / Toggle Window" (SettingsView.svelte:100-117) |
| `max_items_per_directory` | `50` | clipboard.rs:15; SettingsView.svelte:76 | Segmented control **30 / 50 / 100 / 200 / ∞(-1)** under "Storage / Max items per folder — Oldest items are automatically deleted when the limit is reached." (SettingsView.svelte:151-171) |
| `auto_start` | `true` (enabled on first run) | lib.rs:136-142 | **No UI toggle in SettingsView** (commands `set_autostart`/`get_autostart` exist but are never invoked from frontend) |

- `update_setting` special case: changing `mouse_edge_enabled` immediately updates the Rust atomic (lib.rs:66-73).
- Settings view also shows static "Information": Version **"0.1.0"** (hard-coded, stale vs app 0.2.0) and Developer **"newfull5"** (SettingsView.svelte:172-182).
- Additional storage: `localStorage["windowHeight"]` (window height persistence, App.svelte:140-146, 345).

### 1.10 Auto-start

- Exists: **yes** — `tauri-plugin-autostart` 2.5.1 with `MacosLauncher::LaunchAgent`, no extra args (lib.rs:106-109; Cargo.toml:38). Enabled by default on first run (when `auto_start` setting absent) (lib.rs:136-142). Commands `set_autostart(enabled)` / `get_autostart()` (lib.rs:78-94). No settings UI for it.

### 1.11 Auto-update

- Exists: **no**. No updater plugin, no Sparkle equivalent, nothing in tauri.conf.json.

### 1.12 Tray icon

- Exists: **yes**, on both platforms (lib.rs:148-226).
- Menu items (both platforms, lib.rs:148-150): `"Show App"` → `toggle_main_window`; `"Quit PasteSheet"` → `app.exit(0)`.
- Left-click on tray icon (MouseButton::Left, ButtonState::Down) toggles the main window; menu opens on right-click only (`show_menu_on_left_click(false)`) (lib.rs:179, 189-199, 205, 215-225).
- Icon: macOS uses `iconTemplate.png` / `iconTemplate@2x.png` chosen by display scale factor (≥2.0 → @2x), loaded with `image` crate, `icon_as_template(true)` for menu-bar dark/light adaptation (lib.rs:151-177). Non-macOS uses the default window icon, no template mode (lib.rs:172-173, 201-204).

### 1.13 Keyboard handling (frontend — exhaustive)

Global handler: `App.svelte handleKeyDown` on `svelte:window` (App.svelte:354-530, 532). Every keydown also resets the auto-hide timer (App.svelte:355).

**Escape (priority cascade, App.svelte:359-385):**
1. Confirm/input modal open → close modal.
2. Detail modal open → close detail.
3. Editing an item → cancel edit.
4. Settings view → back to directories.
5. Search input focused or query non-empty → clear query (+ blur input).
6. Otherwise → `toggle_main_window` (hide app).

**While confirm modal open** (Modal.svelte:27-57, capture-phase window keydown, stops propagation; plus App.svelte:386-400 blocks everything else):
- `Escape` → cancel. `Enter` → confirm (submits input value if input modal). `ArrowLeft`/`ArrowRight` → swap focus between Confirm and Cancel buttons (skipped while an input/textarea is focused). All other keys suppressed by App handler.

**While Detail modal open:** all keys ignored except Escape (App.svelte:401-403; DetailModal.svelte:23-28).

**While editing an item (input focused):** `Cmd/Ctrl+Enter` → save edit (App.svelte:404-409).

**Type-to-search:** any printable key (`key.length === 1`) or `Backspace`, with no Cmd/Ctrl/Alt, when not in an input → focuses header search input (App.svelte:410-414).

**Navigation (active when not in an input, or when in the search input; App.svelte:424-477):**
- `ArrowDown` → `selectedIndex = (selectedIndex + 1) % listCount` (wraps). `ArrowUp` → wraps backwards. List count = folders+items in search mode; directories+1 ("New Folder" row) in directory view; items+1 ("New Item" row) in item view (App.svelte:415-422, 425-436).
- `ArrowRight`/`ArrowLeft` in search mode (focus not in search input) → cycle item action-button focus 0→2 (Paste/Edit/Delete) via `searchView.handleArrowKey` (App.svelte:437-444; SearchView.svelte:37-53).
- `ArrowRight`/`ArrowLeft` without search:
  - Items view: first offered to `itemView.handleArrowKey` to cycle button focus Paste(0)/Edit(1)/Delete(2); returns false at the edges (App.svelte:448-455; ItemView.svelte:92-115).
  - `ArrowRight` in directories view → open selected directory (App.svelte:456-464).
  - `ArrowLeft` in items view → back to directories; in settings view → back to directories (App.svelte:465-474).
- Selection index is clamped reactively when the list shrinks (App.svelte:117-131). Selected row auto-scrolls into view (`scrollIntoView({behavior:"smooth", block:"nearest"})`, DirectoryView.svelte:14-18, ItemView.svelte:66-77, SearchView.svelte:15-19).

**Enter while search input focused (App.svelte:478-491):** search mode → execute selected (open folder, or item action by button focus); directories view → open selected directory; items view → `itemView.executeSelectedAction()`.

**When not in any input (App.svelte:492-529):**
- `Cmd/Ctrl+Backspace` → delete selected (directory → confirm modal; item → confirm modal; in search mode picks folder vs item by index) (App.svelte:498-512).
- `Space` (items view, no search) → open Detail modal for selected item (App.svelte:513-516). **This is the only trigger for the Detail modal.**
- `Enter` (no search): directories view → open selected dir, or if selection is on the "New Folder" row → start inline folder creation; items view → `executeSelectedAction()` (Paste/Edit/Delete per button focus, or start "New Item" creation when selection is on that row) (App.svelte:517-528; ItemView.svelte:78-91).

**Inline create — folder (DirectoryView.svelte:95-109):** `Enter` save, `Escape` cancel, blur cancels; keydown stops propagation.

**Inline create — item (ItemView.svelte:153-204):** memo input: `Enter` → focus content textarea, `Escape` cancel. Content textarea: `Cmd/Ctrl+Enter` → save (placeholder says "Content (⌘+Enter to save)..."), `Escape` cancel.

**Settings shortcut recording (SettingsView.svelte:30-50):** captures any keydown when recording; requires a modifier; ignores pure modifier keys; window click cancels.

**Context menu (ContextMenu.svelte:8-23):** `Escape` closes; click outside closes.

**HistoryItem row:** `Enter` selects the row if not selected (HistoryItem.svelte:56-60); action buttons stop Enter propagation (HistoryItem.svelte:113, 123, 133).

### 1.14 Modals

1. **Confirm/Input modal** (Modal.svelte; state `modalConfig` in App.svelte:55-88):
   - "Delete Folder": message `Are you sure you want to delete folder "<name>"? All items inside will be lost.`, danger style, confirm "Delete" / cancel "Cancel" (App.svelte:241-256).
   - "Rename Folder": message "Enter new name for the folder:", text input prefilled with old name, confirm "Rename" (App.svelte:257-274).
   - "Delete Item": message "Are you sure you want to delete this item?", danger, confirm "Delete" (App.svelte:312-328).
   - Confirm button auto-focused after 50 ms (non-input modals) (Modal.svelte:15-17); input auto-focused for input modals (Modal.svelte:74-81). Backdrop click cancels (Modal.svelte:64).
2. **Detail modal** (DetailModal.svelte): trigger = Space on selected item. Title "Detail View", header with **Copy** (writes `navigator.clipboard.writeText(content)`) and **Close** buttons, body = full content in `<pre>` monospace, scrollable. Backdrop click closes (DetailModal.svelte:31-68).
3. **Context menu** (ContextMenu.svelte): trigger = right-click on a directory row. Options: "Rename", "Delete" (danger red) (DirectoryView.svelte:114-125).

### 1.15 Tauri commands (complete list, lib.rs:11-102, registered 235-253)

```rust
fn get_clipboard_history() -> Result<Vec<db::PasteItem>, String>            // lib.rs:11-14
fn create_history_item(content: String, directory: String, memo: Option<String>) -> Result<i64, String>  // lib.rs:15-22
fn paste_text(text: String) -> Result<(), String>                           // lib.rs:23-26
fn toggle_main_window(app: AppHandle)                                       // lib.rs:27-30
fn get_directories() -> Result<Vec<db::DirectoryInfo>, String>              // lib.rs:31-34
fn create_directory(name: String) -> Result<i64, String>                    // lib.rs:35-38
fn rename_directory(old_name: String, new_name: String) -> Result<(), String> // lib.rs:39-42
fn delete_directory(name: String) -> Result<(), String>                     // lib.rs:43-46
fn update_history_item(id: i64, content: String, directory: String, memo: Option<String>) -> Result<(), String> // lib.rs:47-57
fn delete_history_item(id: i64) -> Result<(), String>                       // lib.rs:58-61
fn get_setting(key: String) -> Result<Option<String>, String>               // lib.rs:62-65
fn update_setting(key: String, value: String) -> Result<(), String>         // lib.rs:66-73
fn update_shortcut(app: AppHandle, shortcut: String) -> Result<(), String>  // lib.rs:74-77
fn set_autostart(app: AppHandle, enabled: bool) -> Result<(), String>       // lib.rs:78-89
fn get_autostart(app: AppHandle) -> Result<bool, String>                    // lib.rs:90-94
fn start_height_resize(window: tauri::WebviewWindow)                        // lib.rs:95-98
fn stop_height_resize(window: tauri::WebviewWindow) -> f64                  // lib.rs:99-102
```

Backend→frontend events: `"clipboard-updated"` (clipboard.rs:102), `"window-visible"` (bool) (window_manager.rs:25, 66, 169, 181).

---

## 2. Design

### 2.1 Window config (tauri.conf.json:12-33)

- `withGlobalTauri: true`, `macOSPrivateApi: true`.
- Window: 380×800, `resizable false`, `fullscreen false`, `decorations false`, `transparent true`, `shadow false` (shadow drawn in CSS instead), `alwaysOnTop true`, `visible false`, `focus false`. CSP `null`.
- Bundle icons: 32x32.png, 128x128.png, 128x128@2x.png, icon.icns, icon.ico (tauri.conf.json:37-43); targets `"all"`.

### 2.2 Theme tokens (frontend/src/app.css:15-56)

| Token | Value |
|---|---|
| `--color-accent` | `rgb(220, 220, 87)` (≈ `#DCDC57`, yellow) |
| `--color-bg-app` | `#0e1525` |
| `--color-bg-modal` | `rgba(18, 18, 18, 0.98)` |
| `--color-bg-container` | `rgba(18, 18, 18, 0.98)` |
| `--color-bg-item` | `rgba(255, 255, 255, 0.05)` |
| `--color-text-main` | `#ffffff` |
| `--color-text-sub` | `#68748d` |
| `--color-danger` / `--color-accent-danger` | `#ff4444` |
| `--shadow-glow` | `0 0 8px var(--color-accent)` |
| `--shadow-danger-glow` | `0 4px 12px rgba(255, 68, 68, 0.3)` |
| `--transition-app-container` | `transform 0.35s cubic-bezier(0.25, 1, 0.5, 1), opacity 0.3s ease-out` |
| animations | `blink 1s step-end infinite` (cursor); `slideIn 0.2s ease-out` |

Body: transparent background, system sans font (`font-sans`), overflow hidden (app.css:3-13). **Dark theme only — no light mode / no `prefers-color-scheme` handling anywhere.**

### 2.3 UI layout structure (component hierarchy)

```
App.svelte (root container — slide-in panel)
├─ resize handle (bottom, h-12px strip with 32×3px pill)
├─ padded column (p-4 = 16px, pb-3 = 12px)
│  ├─ Header.svelte (back btn ◀ | title/search overlay | settings btn ⚙)
│  └─ content area (flex-1, relative)
│     ├─ SearchView.svelte   (when searchQuery non-empty)  [fly y:10 150ms]
│     ├─ DirectoryView.svelte (view "directories")          [fly x:-10 150ms]
│     ├─ ItemView.svelte      (view "items")                 [no transition]
│     └─ SettingsView.svelte  (view "settings")              [fly y:10 150ms]
├─ Modal.svelte (confirm / input)
└─ DetailModal.svelte
```

ItemView/SearchView render rows via `HistoryItem.svelte`. UI primitives: `ui/Button.svelte`, `ui/Input.svelte`, `ui/Toggle.svelte`, `ui/ContextMenu.svelte`.

### 2.4 Root container (App.svelte:533-548)

- Full-size panel: `bg-bg-container` (rgba(18,18,18,0.98)), **left-rounded corners 16px** (`rounded-l-[16px]`), 1px left/top/bottom border `white/10`, shadow `-4px 0 15px rgba(0,0,0,0.5)`.
- Slide animation: visible → `opacity-100 translate-x-0`; hidden → `opacity-0 translate-x-[60px] pointer-events-none`; transition `transform 0.35s cubic-bezier(0.25,1,0.5,1), opacity 0.3s ease-out`. Container gets `pointer-events-none` while a modal/detail is open.
- Resize handle: absolute bottom strip height 12px (`h-3`), centered pill `w-8 h-[3px]` (32×3px) `rounded-full bg-white/10`, hover `bg-white/30`, `cursor-ns-resize`, transition colors 150ms (App.svelte:543-548).

### 2.5 Header (Header.svelte:45-163)

- `margin-bottom: 20px`, `min-height: 40px`.
- Title `h1`: color accent, **font-size 22px, weight 500, letter-spacing 0.03em**, `padding-left 8px`, ellipsis truncation; blinking cursor `|` appended via `::after` (`blink 1s step-end infinite`). In folder/settings view (`showBack`): `h1.view-folder` → **18px, opacity 0.9**.
- Search input overlays title (absolute, same font 22px/500/0.03em, transparent bg, no border, accent color, opacity 0 → 1 on `.active`/focus, transition opacity 0.2s). In folder view: 18px. Title hides (opacity 0) when query present or input focused (`header-title-container:focus-within h1 {opacity: 0}` app.css:184-186). Placeholder "Search Anything...".
- Back button `◀`: transparent, accent color, 16px, padding 4px 8px, radius 6px, hover `rgba(255,255,255,0.1)`.
- Settings button `⚙`: transparent, accent, 20px, opacity 0.7, padding 6px, radius 8px; hover: bg `rgba(255,255,255,0.1)`, opacity 1, **rotate(30deg)**.

### 2.6 Directory list (DirectoryView.svelte:128-221)

- List: column, `gap 4px`, `padding-right 2px`, scrollbar: width **4px**, thumb `rgba(220,220,87,0.2)` radius 2px, hover `rgba(220,220,87,0.4)`, track transparent (also `scrollbar-width: thin`).
- Row `.dir-item`: padding **12px 12px**, radius 6px, transparent bg, `border-bottom 1px solid rgba(255,255,255,0.03)`, transition background 0.1s; hover bg `rgba(255,255,255,0.05)`; **selected bg `rgba(220,220,87,0.1)`**.
- Left indicator bar `::before`: **4×18px**, radius 2px, color `--color-text-sub` at opacity 0.4, `margin-right 12px`; hover/selected: accent color, opacity 1, glow `0 0 8px accent`.
- Name: 15px, weight 400, ellipsis. Count badge: 12px, text-sub on `rgba(255,255,255,0.08)`, padding 2px 8px, radius 10px, min-width 24px, centered.
- Rows animate with `flip 300ms` + `fly y:20 200ms`.
- "New Folder" row `.btn-new` (shared style, app.css:69-109): `border-top 1px solid rgba(255,255,255,0.05)`, `margin-top 12px`, opacity 0.8, padding 10px 12px, **min-height 44px**, font 14px, color text-sub, radius 6px; `＋` prefix in accent, 18px bold, margin-right 12px; hover/selected: opacity 1, bg `rgba(220,220,87,0.05)`. Item-view variant `.accent-text` colors the label accent.

### 2.7 History item row (HistoryItem.svelte:141-368)

- Row: padding **12px 14px**, radius 6px, **min-height 44px**, transparent bg, `border-bottom 1px solid rgba(255,255,255,0.03)`, transition `all 0.2s cubic-bezier(0.4,0,0.2,1)`, overflow hidden.
- Hover bg `rgba(255,255,255,0.05)`; **selected bg `rgba(220,220,87,0.08)`**, expands (`max-height 800px`, `min-height fit-content`, overflow visible, `align-items stretch`).
- Left accent bar `::before`: **4×16px**, accent color, opacity 0.3, radius 2px, `margin-right 16px`; selected: stretches full height (`height auto; align-self stretch`), opacity 1, glow `0 0 8px accent`; hover: opacity 1 + glow.
- Memo: 13px, weight 500, color **`#e2e2b6`**, letter-spacing 0.03em, line-height 1.4, single-line ellipsis, max-width 70%.
- Folder badge (search results only): 10px, text-sub on `rgba(255,255,255,0.08)`, padding 1px 6px, radius 4px, uppercase, letter-spacing 0.05em, opacity 0.6, right-aligned.
- Content (collapsed): 14px, `rgba(255,255,255,0.7)`, single-line ellipsis.
- Content (selected/expanded): white, `white-space: pre-wrap`, **max-height 350px** scrollable, line-height 1.6, margins 4px top / 16px bottom, `user-select: none`; thin scrollbar 4px, thumb `rgba(220,220,87,0.2)` radius 2px / hover 0.4.
- Meta row (selected only): date `toLocaleString()` (HistoryItem.svelte:42-49,103), 11px monospace, text-sub, opacity 0.6, `border-top 1px solid rgba(255,255,255,0.05)`, padding 8px top/bottom.
- Action buttons (selected only): row `gap 8px`, `border-top 1px solid rgba(255,255,255,0.1)`, padding-top 12px, padding-bottom 4px. `.btn-mini`: padding 4px 10px, 11px, radius 4px, bg `rgba(255,255,255,0.05)`, border `1px solid rgba(255,255,255,0.1)`, color text-sub; hover bg `rgba(255,255,255,0.1)` white text. Active/focused (`.primary`): **accent bg, black text**. Delete: hover/active **`#ff5555` bg, white text**.
- Edit mode: memo input (`.memo-area`): bg `rgba(220,220,87,0.05)`, border `1px solid rgba(220,220,87,0.3)`, accent text, radius 4px, padding 8px 10px, 13px/600. Content textarea (`.edit-area`): min-height **120px**, bg `rgba(255,255,255,0.03)`, border `1px solid rgba(220,220,87,0.2)`, white text, padding 10px, radius 6px, 14px, line-height 1.5, `resize: vertical`; focus: accent border, bg `rgba(220,220,87,0.08)`, ring `0 0 0 2px rgba(220,220,87,0.1)`. Same styles for the inline-create form (`.inline-memo`/`.inline-content`, app.css:111-165).
- Item list scrollbar (ItemView.svelte:229-238): width **6px**, thumb `rgba(220,220,87,0.2)` radius 10px, hover 0.4. Empty state: "No items found in this folder", text-sub 14px, padding 40px 0 (ItemView.svelte:209-211, 239-244).

### 2.8 Search view (SearchView.svelte:124-209)

- Sections gap 20px; section header: **11px / 700 / uppercase / letter-spacing 0.1em**, text-sub, opacity 0.7, padding-left 8px ("Folders", "Items").
- Folder result row: padding 10px 12px, radius **8px**, hover `rgba(255,255,255,0.05)`, selected `rgba(220,220,87,0.1)`; icon bar 4×16px (same accent/glow rules); name 14px; count badge same as directory view.
- Empty state: "No matches found for your search.", padding 60px 0, 14px.

### 2.9 Settings view (SettingsView.svelte:184-313)

- Column gap 24px, group gap 12px, scrollable. Group title: 13px/600 uppercase, letter-spacing 0.05em, text-sub ("Shortcut", "General", "Storage", "Information").
- Rows (shortcut/info/timeout): bg `rgba(255,255,255,0.03)`, radius **12px**, padding 12px (timeout rows 10px 12px). Labels 14px/500 white; descriptions 12px text-sub.
- Shortcut chip: bg `rgba(255,255,255,0.08)`, radius 8px, padding 6px 14px, 13px/600, letter-spacing 0.05em; hover `rgba(255,255,255,0.14)`; recording: bg `rgba(99,102,241,0.25)`, text `rgba(165,180,252,1)`, `pulse 1.2s ease-in-out infinite` (opacity 1→0.6).
- Segmented control: container bg `rgba(255,255,255,0.05)`, radius 10px, padding 3px, gap 4px; segment padding 4px 10px, radius 7px, 13px/500 text-sub; hover white text; active: bg `rgba(255,255,255,0.15)`, white text.
- Toggle (Toggle.svelte:25-84): container bg `rgba(255,255,255,0.03)`, radius 12px, padding 12px, hover `rgba(255,255,255,0.08)`; label 15px/500; description 12px text-sub. Switch: **44×24px**, bg `rgba(255,255,255,0.1)` radius 20px; checked: accent bg. Handle: **18×18px** white circle at 3px/3px, shadow `0 2px 4px rgba(0,0,0,0.2)`, checked → `translateX(20px)`; 0.3s cubic-bezier(0.4,0,0.2,1) (animation suppressed until mounted).

### 2.10 Modals

- Confirm modal (Modal.svelte:60-102): full-screen overlay `bg-black/60 backdrop-blur-sm`, z-100, fade 200ms. Card: `bg-bg-container`, border white/10, **radius 16px (`rounded-2xl`)**, padding 24px (`p-6`), `max-w-sm`, shadow-2xl, scale-in 200ms from 0.95. Title: 18px bold accent. Message: 14px, white/90, mb-6. Input: `bg-black/30`, border white/10, radius 8px, px-3 py-2, focus border accent. Buttons right-aligned gap-3: Cancel `bg-white/5` hover white/10 focus white/20 + scale-105; Confirm — danger: `bg-red-500` white, hover red-600, shadow `0 4px 12px rgba(239,68,68,0.3)`, focus scale-105 + `0 6px 24px rgba(239,68,68,0.6)`; normal: accent bg, `text-bg-app`, hover brightness-110, shadow `0 4px 12px rgba(220,220,87,0.3)`.
- Detail modal (DetailModal.svelte:31-68): overlay `bg-black/60 backdrop-blur-sm` z-50, fade 200ms. Card: bg **`#1e1e1e`**, border white/10, radius 12px (`rounded-xl`), `w-[90%] max-w-3xl max-h-[80vh]`, scale 200ms from 0.95. Header: p-4, `border-b white/10`, `bg-white/5`, title 18px bold; Copy (primary) + Close (secondary) small buttons. Body: p-6, bg **`#1a1a1a`**, `<pre>` text-sub 14px (`text-sm`) `font-mono whitespace-pre-wrap break-words leading-relaxed`.
- Context menu (ContextMenu.svelte:24-40): fixed at cursor, z-9999, `min-w-[120px]`, bg `#1e1e1e`, border white/10, radius 8px, padding 4px (`p-1`), shadow-xl, scale 100ms from 0.95. Options: full-width, px-3 py-2, radius 4px, 12px (`text-xs`) medium; normal hover `bg-white/10`; danger: `text-red-400`, hover `bg-red-500/10`.

### 2.11 Buttons / inputs (ui/Button.svelte:7-19, ui/Input.svelte:25)

- Button variants: `primary` accent bg + black text hover brightness-110; `secondary` `bg-white/10` + border white/10 hover white/20; `danger` `bg-red-500/20` red-500 text; `ghost` transparent. Sizes: `sm` px-3 py-1 text-xs bold rounded(4px); `md` px-4 py-2 text-sm medium rounded-lg(8px); `lg` px-6 py-3 text-base bold rounded-xl(12px). Transition all 200ms; disabled opacity-50.
- Input default: `bg-black/30`, border white/10, radius 8px (`rounded-lg`), px-3 py-2, white text, focus border accent.

### 2.12 Animations/transitions summary

- App show/hide: translateX(60px)+fade, 0.35s `cubic-bezier(0.25,1,0.5,1)` / opacity 0.3s ease-out (App.svelte:535-540; physical hide deferred 350 ms in Rust window_manager.rs:27-37; mouse-edge hide deferred 150 ms window_manager.rs:182).
- View switches: Svelte `fly` — search/settings `y:10, 150ms`; directories `x:-10, 150ms`; items view none (App.svelte:568, 589, 621).
- List rows: `animate:flip 300ms` + `transition:fly y:20 200ms` (DirectoryView.svelte:70-71; ItemView.svelte:121-122).
- Modals: fade 200ms overlay + scale 200ms (start 0.95); context menu scale 100ms.
- Header title blinking caret `blink 1s step-end infinite`; settings gear hover rotate 30deg; shortcut recording `pulse 1.2s`.

### 2.13 Dark/light mode

- None. Hard-coded dark palette. The only theme-adaptive element is the macOS tray template icon (`icon_as_template(true)`, lib.rs:177).

---

## 3. Data

### 3.1 DB schema (db.rs:41-103)

```sql
CREATE TABLE IF NOT EXISTS directories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);                                                       -- db.rs:43-50

INSERT OR IGNORE INTO directories (name) VALUES ('Clipboard');  -- db.rs:51-54

CREATE TABLE IF NOT EXISTS paste_sheets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    directory TEXT NOT NULL,
    memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (directory) REFERENCES directories(name)
);                                                       -- db.rs:55-65

-- migration: add memo column if missing (PRAGMA table_info check) db.rs:66-85
-- backfill: INSERT OR IGNORE directories from distinct paste_sheets.directory db.rs:86-90

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);                                                       -- db.rs:91-97

INSERT OR IGNORE INTO settings (key, value) VALUES ('mouse_edge_enabled', 'true'); -- db.rs:98-101
```

### 3.2 DB file location

- `dirs::data_dir()/paste_sheets.db` (db.rs:36-40) — **not** in an app-named subfolder:
  - macOS: `~/Library/Application Support/paste_sheets.db`
  - Windows: `C:\Users\<user>\AppData\Roaming\paste_sheets.db`
- A new `Connection::open` per operation (no pooling).

### 3.3 Settings storage

- All app settings in the SQLite `settings` table (see §1.9). Window height in webview `localStorage["windowHeight"]` (App.svelte:140-146, 345). Auto-start state additionally lives in the OS (LaunchAgent / registry) via the autostart plugin.

---

## 4. Platform branches

Every `#[cfg(...)]`/platform branch, with Windows status:

| # | Location | macOS behavior | Windows behavior |
|---|---|---|---|
| 1 | src-tauri/src/main.rs:1 | n/a | `windows_subsystem = "windows"` in release — no console window |
| 2 | lib.rs:132-133 | `ActivationPolicy::Accessory` — no Dock icon | **No equivalent**; no `skipTaskbar` → window shows in taskbar |
| 3 | lib.rs:151-171 | Tray icon from `iconTemplate.png`/`@2x.png` by scale factor | lib.rs:172-173: default window icon (`#[cfg(not(macos))]`) |
| 4 | lib.rs:174-200 vs 201-226 | Tray with `icon_as_template(true)` | Same tray, menu, click handlers — but **no template mode** |
| 5 | clipboard.rs:121-125 | Extra `restore_prev_app_native()` + 50 ms sleep before keystroke | Skipped |
| 6 | clipboard.rs:127-132 | Paste keystroke: Meta+`raw(9)` (Cmd+V) | clipboard.rs:133-140: Control+`raw(86)` (Ctrl+V) — **implemented** |
| 7 | hotkey.rs:49-78 (`restore_prev_app_native`) | NSWorkspace `runningApplications` → match `localizedName` → `activateWithOptions(1<<1)` | **Function body empty — focus restore unimplemented (no-op)**; pasted keystroke lands wherever OS focus goes |
| 8 | window_manager.rs:5-6 | `objc` imports | n/a |
| 9 | window_manager.rs:41-60 (toggle show) | Repositions to active monitor top-right before show | **No repositioning on show** (window stays wherever it was) |
| 10 | window_manager.rs:76-83 (`start_mouse_edge_monitor`) | Spawns monitoring thread | **Thread not spawned — mouse edge peek missing** |
| 11 | window_manager.rs:88-108 (`set_window_position`) | Active-screen top-right via NSScreen | Falls through to generic branch 109-119: **first** monitor, `(logical_width - 410, 0)` — note hard-coded 410 vs real width 380 |
| 12 | window_manager.rs:130-192 (`setup_mouse_event_monitoring`) | Right-edge show (2 px threshold), auto-hide when mouse leaves window width, 100 ms poll / 500 ms idle, 150 ms hide delay | **Missing (macOS-only fn)** |
| 13 | window_manager.rs:193-230 (`ScreenInfo`, `get_active_screen_info`) | NSScreen multi-monitor geometry, Y-flip math | **Missing** |
| 14 | window_manager.rs:231-238 (`get_mouse_location`) | NSEvent `mouseLocation` | window_manager.rs:239-242: **stub returning `None`** |
| 15 | window_manager.rs:243-246 (`get_screen_width`) | n/a | **stub returning `None`** (dead code) |
| 16 | window_manager.rs:252-287 (`start_height_resize`) | 8 ms mouse-poll resize loop, clamp 300–1400, width fixed 380; macOS Y-axis math | **Body cfg(macos) — height resize is a no-op on Windows** (`stop_height_resize` still returns current height) |
| 17 | Cargo.toml:40-41 | n/a | `winapi` (winuser) dependency declared but **never used in code** |
| 18 | Cargo.toml:43-44 | `objc-foundation` macOS-only dep | n/a |
| 19 | lib.rs:106-109 (autostart init) | `MacosLauncher::LaunchAgent` | Plugin defaults to registry `Run` key on Windows (launcher arg ignored) |

### Tauri plugins (Cargo.toml:20-38; lib.rs:105-114, 124-130)

- `tauri` 2.9.4 with features `macos-private-api` (transparency; macOS-only effect) and `tray-icon` (cross-platform).
- `tauri-plugin-global-shortcut` 2.0 — cross-platform global hotkey; `CommandOrControl` maps to Cmd on macOS / Ctrl on Windows.
- `tauri-plugin-autostart` 2.5.1 — LaunchAgent on macOS, registry Run key on Windows; enabled by default on first run (lib.rs:136-142).
- `tauri-plugin-log` 2 — registered only in debug builds, level Debug (lib.rs:124-130).
- Non-plugin native crates: `arboard` 3 (clipboard, cross-platform), `enigo` 0.6 (keystroke synthesis, cross-platform), `active-win-pos-rs` 0.8 (frontmost app name, cross-platform), `rusqlite` 0.32 bundled, `cocoa`/`objc`/`core-foundation`/`objc-foundation` (macOS only usage), `image` 0.25 (tray icon decode), `dirs` 5.

### Windows gap summary (functional deltas vs macOS)

1. Focus restore to previous app: **missing** (hotkey.rs:49-78) → paste keystroke may target the wrong window.
2. Mouse edge peek: **missing** (window_manager.rs:76-83, 239-246).
3. Window repositioning to active monitor on show: **missing** (window_manager.rs:41-60); initial position uses first monitor with wrong 410 px width constant.
4. Height drag-resize: **missing** (window_manager.rs:252-287).
5. Taskbar hiding: **not configured** (no Accessory equivalent / skipTaskbar).
6. Tray template icon adaptation: macOS-only (uses plain default icon on Windows).
7. Implemented on Windows: clipboard monitor, DB/CRUD, search, global hotkey, Ctrl+V synthesis, tray menu + left-click toggle, autostart, hide-on-close, transparent undecorated always-on-top window.
