# PasteSheets — Claude Code Migration Reference

> This document is structured for AI code-generation agents.
> Feed this as context when generating native (Swift/SwiftUI, Kotlin/Compose, Flutter) code.

---

## 1. Data Models (Source: Rust structs)

```rust
// src-tauri/src/modules/db.rs

#[derive(Serialize, Deserialize)]
pub struct PasteItem {
    pub id: i64,
    pub content: String,       // clipboard text content
    pub directory: String,     // folder name (FK → directories.name)
    pub created_at: String,    // ISO timestamp
    pub memo: Option<String>,  // optional user label
}

#[derive(Serialize, Deserialize)]
pub struct DirectoryInfo {
    pub name: String,  // unique folder name
    pub count: i64,    // number of items in this folder
}
```

### Type Mapping Reference

| Rust | Swift | Kotlin | Dart/Flutter |
|------|-------|--------|--------------|
| `i64` | `Int64` / `Int` | `Long` | `int` |
| `String` | `String` | `String` | `String` |
| `Option<String>` | `String?` | `String?` | `String?` |
| `Vec<T>` | `[T]` | `List<T>` | `List<T>` |
| `bool` | `Bool` | `Boolean` | `bool` |

---

## 2. Database Schema (SQLite)

```sql
CREATE TABLE directories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Default row: INSERT OR IGNORE INTO directories (name) VALUES ('Clipboard');

CREATE TABLE paste_sheets (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    content     TEXT NOT NULL,
    directory   TEXT NOT NULL,        -- references directories.name
    memo        TEXT,                 -- nullable
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (directory) REFERENCES directories(name)
);

CREATE TABLE settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
-- Default: INSERT OR IGNORE INTO settings (key, value) VALUES ('mouse_edge_enabled', 'true');
```

### Settings Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `mouse_edge_enabled` | `"true"/"false"` | `"true"` | Show window when mouse hits screen edge |
| `auto_hide_enabled` | `"true"/"false"` | `"false"` | Auto-hide after inactivity |
| `auto_hide_timeout` | `"3"~"60"` (seconds) | `"5"` | Seconds before auto-hide |
| `shortcut` | shortcut string | `"CommandOrControl+Shift+V"` | Global hotkey |
| `auto_start` | `"true"/"false"` | `"true"` | Launch at login |

---

## 3. Command API Specification

Each command below was a Tauri `invoke()` call. In native apps, these map to repository/service methods.

### 3.1 Clipboard History (CRUD)

```yaml
get_clipboard_history:
  args: none
  returns: PasteItem[]
  order: created_at DESC
  notes: Returns ALL items across all directories

create_history_item:
  args:
    content: String        # required
    directory: String      # required (folder name)
    memo: String?          # optional
  returns: i64             # new item ID

update_history_item:
  args:
    id: i64
    content: String
    directory: String
    memo: String?
  returns: void
  notes: Also updates created_at to CURRENT_TIMESTAMP

delete_history_item:
  args:
    id: i64
  returns: void
```

### 3.2 Directory Management

```yaml
get_directories:
  args: none
  returns: DirectoryInfo[]
  order: "Clipboard" first, then by created_at
  notes: Includes item count per directory via LEFT JOIN

create_directory:
  args:
    name: String           # trimmed, must be non-empty
  returns: i64             # new directory ID
  errors: empty name → InvalidQuery

rename_directory:
  args:
    old_name: String
    new_name: String
  returns: void
  constraints:
    - Cannot rename "Clipboard"
    - Cannot rename TO "Clipboard"
    - new_name must be non-empty
  notes: Uses transaction; updates both directories.name AND paste_sheets.directory

delete_directory:
  args:
    name: String
  returns: void
  constraints: Cannot delete "Clipboard"
  notes: Deletes all paste_sheets items in directory first, then the directory
```

### 3.3 Paste Action

```yaml
paste_text:
  args:
    text: String
  returns: void
  behavior:
    1. Set system clipboard to `text` (arboard)
    2. Restore previous app focus (NSWorkspace on macOS)
    3. Wait 80ms
    4. Restore focus again (double restoration for reliability)
    5. Wait 50ms
    6. Simulate Cmd+V (macOS) or Ctrl+V (Windows) via enigo
  native_replacement:
    macOS: NSPasteboard + NSWorkspace.activateWithOptions + CGEvent keypress
    Android: ClipboardManager + InputMethodManager or AccessibilityService
    iOS: UIPasteboard (paste requires user action in iOS)
```

### 3.4 Window Management

```yaml
toggle_main_window:
  args: app handle
  returns: void
  behavior:
    show:
      - Detect active monitor (NSEvent.mouseLocation → NSScreen.screens)
      - Position window at right edge of active screen
      - window.show() + window.setFocus()
      - Emit "window-visible" = true (after 20ms)
    hide:
      - Emit "window-visible" = false
      - Wait 350ms (for CSS exit animation)
      - window.hide()
  native_replacement:
    macOS: NSPanel / NSWindow with .styleMask and screen positioning
    iOS: N/A (different UX paradigm)
    Android: Overlay window or notification shade widget

start_height_resize:
  args: window
  returns: void
  behavior: Polls mouse Y at 8ms, adjusts window height (300-1400px range)

stop_height_resize:
  args: window
  returns: f64 (final logical height)
```

### 3.5 Settings

```yaml
get_setting:
  args:
    key: String
  returns: String?

update_setting:
  args:
    key: String
    value: String
  returns: void
  side_effects:
    - If key == "mouse_edge_enabled": updates runtime AtomicBool

update_shortcut:
  args:
    shortcut: String       # e.g. "CommandOrControl+Shift+V"
  returns: void
  behavior: Unregister all → register new → save to DB

set_autostart:
  args:
    enabled: bool
  returns: void
  native_replacement:
    macOS: SMAppService.register() (modern) or LaunchAgent plist
    Windows: Registry HKCU\...\Run
    Android: N/A
    iOS: N/A

get_autostart:
  args: none
  returns: bool
```

### 3.6 Clipboard Monitoring (Background)

```yaml
monitor_clipboard:
  type: background thread (spawned at app launch)
  polling_interval: 100ms
  behavior:
    1. Read system clipboard text
    2. Compare with last known content
    3. If changed and non-empty:
       a. find_by_content(text, "Clipboard")
       b. If exists → update_content (bump timestamp)
       c. If new → post_content → cleanup_old_items (max 30 per directory)
       d. Emit "clipboard-updated" to frontend
  native_replacement:
    macOS: NSPasteboard.changeCount polling or NSPasteboard.general observation
    Android: ClipboardManager.OnPrimaryClipChangedListener
    iOS: UIPasteboard.changedNotification (limited in background)
```

### 3.7 Mouse Edge Detection (Background)

```yaml
mouse_edge_monitor:
  type: background thread (spawned at app launch)
  polling_interval: 100ms
  behavior:
    - Get mouse position (NSEvent.mouseLocation)
    - Get active screen bounds
    - If mouse.x >= screen.right - 2px AND window hidden:
        → show window at right edge, mark auto_hide = true
    - If mouse.x < screen.right - window_width AND auto_hide:
        → hide window (150ms delay)
  native_replacement:
    macOS: CGEvent tap or NSEvent.addGlobalMonitorForEvents
    Other platforms: Not applicable
```

---

## 4. UI Component Tree

```
App (root state manager)
│
├── Header
│   ├── BackButton          — visible when in ItemView or SettingsView
│   ├── Title               — "PasteSheet" / folder name / "Settings" / "Search results"
│   ├── SearchInput         — overlays title, auto-focus on typing
│   └── SettingsButton      — gear icon
│
├── DirectoryView           — default view
│   ├── DirItem[]           — clickable rows: name + item count
│   │   └── ContextMenu     — right-click: Rename, Delete
│   └── NewFolderButton     — inline input on click
│
├── ItemView                — shown after selecting a directory
│   ├── HistoryItem[]       — selectable rows
│   │   ├── [collapsed]     — memo label + content preview (single line, ellipsis)
│   │   ├── [selected]      — full content (pre-wrap, scrollable, max 350px)
│   │   │   ├── MetaRow     — formatted date
│   │   │   └── ActionRow   — [Paste] [Edit] [Delete] buttons
│   │   └── [editing]       — memo input + content textarea + [Save] [Cancel]
│   └── NewItemButton       — inline memo + content inputs
│
├── SearchView              — shown when searchQuery is non-empty
│   ├── FoldersSection      — matching directories
│   │   └── DirResult[]     — icon + name + count
│   └── ItemsSection        — matching items (all directories)
│       └── HistoryItem[]   — with folder label badge
│
├── SettingsView
│   ├── ShortcutGroup
│   │   └── ShortcutKey     — click to record, displays formatted keys (⌘ ⇧ ⌥)
│   ├── GeneralGroup
│   │   ├── Toggle: Launch at Login
│   │   ├── Toggle: Mouse Edge Detection
│   │   ├── Toggle: Auto-hide
│   │   └── TimeoutSelector — segmented control [3s, 5s, 10s, 30s, 60s]
│   └── InfoGroup
│       ├── Version
│       └── Developer
│
├── Modal                   — confirm/input dialog
│   ├── Title + Message
│   ├── [optional] TextInput
│   └── [Cancel] [Confirm/Delete] buttons
│
└── DetailModal             — full content viewer
    ├── Title bar + [Copy] [Close]
    └── Scrollable pre-formatted content
```

### View Navigation State Machine

```
States: directories | items | settings | search (overlay)

directories  →  items       : select folder (Enter/Click/ArrowRight)
items        →  directories : back (ArrowLeft/BackButton/Escape)
directories  →  settings    : settings button
settings     →  directories : back (ArrowLeft/Escape)
ANY          →  search      : type any character (searchQuery becomes non-empty)
search       →  previous    : Escape or clear search
```

---

## 5. Event Flow (IPC)

### Backend → Frontend (Tauri emit)

| Event | Payload | Triggers |
|-------|---------|----------|
| `clipboard-updated` | `()` | Clipboard monitor detects new content |
| `window-visible` | `bool` | Window toggled (hotkey, tray, mouse edge) |

### Frontend → Backend (Tauri invoke)

| Lifecycle Phase | Commands Called |
|----------------|----------------|
| App mount | `get_setting` ×3, `get_directories`, `get_clipboard_history` |
| Window becomes visible | `get_directories`, `get_clipboard_history` |
| Clipboard updated event | `get_directories`, `get_clipboard_history` |
| User pastes item | `toggle_main_window`, then `paste_text` (50ms delay) |
| User creates folder | `create_directory` → `get_directories` |
| User renames folder | `rename_directory` → `get_directories` |
| User deletes folder | `delete_directory` → `get_directories` |
| User creates item | `create_history_item` → `get_clipboard_history` + `get_directories` |
| User edits item | `update_history_item` → `get_clipboard_history` + `get_directories` |
| User deletes item | `delete_history_item` → `get_clipboard_history` + `get_directories` |
| User changes setting | `update_setting` or `set_autostart` |
| User changes shortcut | `update_shortcut` |
| User resizes window | `start_height_resize` → `stop_height_resize` |

---

## 6. Keyboard Navigation Spec

```
Context: No input focused, no modal open

↑/↓          → Move selection index (wraps around)
→            → Directory: enter folder / Item: next action button (Paste→Edit→Delete)
←            → Item (btn>0): prev button / Item (btn=0): back to directories
Enter        → Directory: open / Item: execute focused button / Search: execute
Space        → Item: open DetailModal
Cmd+Delete   → Delete selected item or directory (with confirmation modal)
Escape       → Close modal → close detail → cancel edit → exit settings → clear search → hide window
Any char     → Focus search input (auto-enter search mode)

Context: Search input focused
↑/↓          → Move selection
Enter        → Execute action on selected result
Escape       → Clear search and blur

Context: Edit mode (input/textarea focused)
Cmd+Enter    → Save edit
Escape       → Cancel edit

Context: Modal open
Enter        → Confirm
Escape       → Cancel
←/→          → Switch focus between Cancel/Confirm buttons
```

---

## 7. Business Rules & Constraints

1. "Clipboard" directory is immutable: cannot be renamed or deleted
2. Max 30 items per directory in auto-clipboard capture (oldest deleted first)
3. Duplicate clipboard content updates timestamp instead of creating new entry
4. Window dimensions: width fixed 380px, height 300–1400px (user resizable)
5. Window position: always right edge of active monitor, top-aligned
6. Auto-start enabled by default on first run
7. Mouse edge threshold: 2px from right edge to show, window-width distance to hide
8. Paste sequence requires double focus-restoration with delays for reliability
9. Clipboard polling: 100ms interval
10. Window hide animation: 350ms CSS transition before physical hide
11. Empty/whitespace-only clipboard content is ignored
