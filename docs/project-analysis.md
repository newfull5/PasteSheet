# PasteSheets 프로젝트 분석서

## 1. 프로젝트 개요

**PasteSheet**는 macOS/Windows용 클립보드 매니저 데스크톱 앱이다.
- **스택**: Tauri 2 (Rust 백엔드) + Svelte (프론트엔드) + SQLite (로컬 DB) + Tailwind CSS
- **형태**: 화면 우측에 상주하는 패널형 앱 (Always on Top, 데코레이션 없음, 투명 배경)
- **트레이**: 시스템 트레이 아이콘으로 상주, 좌클릭 토글/우클릭 메뉴

---

## 2. 전체 기능 목록

### 2.1 클립보드 모니터링
- 시스템 클립보드를 100ms 폴링으로 감시
- 새 텍스트 감지 시 "Clipboard" 디렉토리에 자동 저장
- 동일 내용 중복 저장 방지 (기존 항목 timestamp 갱신)
- 디렉토리당 최대 30개 항목 유지 (오래된 것부터 자동 삭제)
- 클립보드 변경 시 프론트엔드에 `clipboard-updated` 이벤트 발행

### 2.2 붙여넣기 (Paste)
- 항목 선택 → 클립보드에 복사 → 이전 앱 복원 → Cmd+V (macOS) / Ctrl+V (Windows) 키 시뮬레이션
- 이전 활성 앱 기억/복원 (NSWorkspace API 사용)
- 더블 포커스 복원 + 딜레이로 안정성 확보

### 2.3 디렉토리(폴더) 관리
- 기본 "Clipboard" 디렉토리 (삭제/이름변경 불가)
- 디렉토리 생성 / 이름변경 / 삭제
- 디렉토리별 항목 수 표시
- 우클릭 컨텍스트 메뉴 (Rename, Delete)

### 2.4 히스토리 아이템 관리
- 아이템 CRUD (생성/조회/수정/삭제)
- 각 아이템: content (텍스트), directory (소속 폴더), memo (선택적 라벨), created_at
- 인라인 편집 모드 (memo + content textarea)
- 수동 아이템 생성 (New Item 버튼)

### 2.5 검색
- 헤더 검색창에서 전역 검색 (폴더명 + 아이템 content + memo)
- 검색 결과: "Folders" 섹션 + "Items" 섹션으로 분리 표시
- 검색 중에도 키보드 네비게이션 완전 지원

### 2.6 키보드 네비게이션
- **Arrow Up/Down**: 리스트 항목 이동 (순환)
- **Arrow Right**: 디렉토리 → 아이템 뷰 진입 / 아이템 내 버튼 포커스 이동 (Paste→Edit→Delete)
- **Arrow Left**: 아이템 뷰 → 디렉토리 뷰 복귀 / 버튼 포커스 역이동
- **Enter**: 디렉토리 열기 / 선택된 버튼 실행
- **Space**: 아이템 상세 보기 (DetailModal)
- **Cmd+Backspace**: 선택 항목 삭제
- **Escape**: 모달 닫기 → 상세뷰 닫기 → 편집 취소 → 설정 닫기 → 검색 초기화 → 윈도우 숨기기
- **아무 키 입력**: 자동으로 검색창 포커스

### 2.7 윈도우 관리
- 글로벌 단축키로 토글 (기본: Cmd+Shift+V, 커스터마이징 가능)
- 화면 우측 끝에 위치 고정 (활성 모니터 감지)
- 마우스 엣지 감지: 마우스가 화면 우측 끝에 도달하면 자동 표시, 벗어나면 자동 숨기기
- 윈도우 표시/숨기기 애니메이션 (CSS transition: opacity + translateX)
- 하단 리사이즈 핸들로 높이 조절 (Rust 측 마우스 폴링, 300~1400px)
- 높이 localStorage 저장/복원
- 닫기 버튼 → 숨기기 (종료 아님)
- 멀티모니터 지원 (활성 스크린 감지)

### 2.8 설정
- **단축키 변경**: 키 녹음 방식으로 글로벌 단축키 커스터마이징
- **Launch at Login**: macOS LaunchAgent 기반 자동 시작 (기본 활성)
- **Mouse Edge Detection**: 마우스 엣지 감지 토글
- **Auto-hide**: 비활성 시 자동 숨기기 (3/5/10/30/60초 선택)
- 버전/개발자 정보 표시

### 2.9 시스템 트레이
- macOS: 템플릿 아이콘 (Retina 대응 @2x)
- 좌클릭: 윈도우 토글
- 우클릭 메뉴: Show App / Quit
- Accessory 활성화 정책 (Dock에 표시 안 됨)

### 2.10 데이터 저장
- SQLite DB (`~/Library/Application Support/paste_sheets.db`)
- 3개 테이블: `directories`, `paste_sheets`, `settings`
- 마이그레이션: memo 컬럼 자동 추가, 기존 디렉토리 자동 등록

---

## 3. 필요 메소드 목록

### 3.1 Backend (Rust) — Tauri Commands

| Command | 시그니처 | 설명 |
|---------|----------|------|
| `get_clipboard_history` | `() -> Vec<PasteItem>` | 전체 히스토리 조회 (최신순) |
| `create_history_item` | `(content, directory, memo?) -> i64` | 수동 아이템 생성 |
| `update_history_item` | `(id, content, directory, memo?) -> ()` | 아이템 수정 |
| `delete_history_item` | `(id) -> ()` | 아이템 삭제 |
| `paste_text` | `(text) -> ()` | 클립보드 복사 + 이전 앱 복원 + 키 시뮬레이션 |
| `toggle_main_window` | `(app) -> ()` | 윈도우 표시/숨기기 토글 |
| `get_directories` | `() -> Vec<DirectoryInfo>` | 디렉토리 목록 (항목 수 포함) |
| `create_directory` | `(name) -> i64` | 디렉토리 생성 |
| `rename_directory` | `(old_name, new_name) -> ()` | 디렉토리 이름변경 |
| `delete_directory` | `(name) -> ()` | 디렉토리 삭제 (하위 아이템 포함) |
| `get_setting` | `(key) -> Option<String>` | 설정값 조회 |
| `update_setting` | `(key, value) -> ()` | 설정값 저장 |
| `update_shortcut` | `(app, shortcut) -> ()` | 글로벌 단축키 변경 |
| `set_autostart` | `(app, enabled) -> ()` | 자동시작 설정 |
| `get_autostart` | `(app) -> bool` | 자동시작 상태 조회 |
| `start_height_resize` | `(window) -> ()` | 높이 리사이즈 시작 |
| `stop_height_resize` | `(window) -> f64` | 높이 리사이즈 종료 (최종 높이 반환) |

### 3.2 Backend — 내부 모듈 메소드

#### `modules::db`
| 메소드 | 설명 |
|--------|------|
| `init_db()` | DB 초기화 + 테이블 생성 + 마이그레이션 |
| `get_path()` | DB 파일 경로 반환 |
| `get_all_contents()` | 전체 아이템 조회 |
| `post_content(content, directory, memo?)` | 아이템 삽입 |
| `update_content(id, content, directory, memo?)` | 아이템 갱신 |
| `find_by_content(content, directory)` | 내용으로 아이템 검색 (중복 체크) |
| `delete_history_item(id)` | 아이템 삭제 |
| `get_directories()` | 디렉토리 목록 + 카운트 |
| `create_directory(name)` | 디렉토리 생성 |
| `rename_directory(old, new)` | 디렉토리 이름변경 (트랜잭션) |
| `delete_directory(name)` | 디렉토리 + 하위 아이템 삭제 |
| `get_setting(key)` | 설정 조회 |
| `set_setting(key, value)` | 설정 저장 (UPSERT) |

#### `modules::clipboard`
| 메소드 | 설명 |
|--------|------|
| `monitor_clipboard(app_handle)` | 클립보드 폴링 스레드 시작 |
| `get_clipboard_text()` | 현재 클립보드 텍스트 읽기 |
| `paste_text(text)` | 클립보드 설정 + 앱 복원 + 키 시뮬레이션 |
| `cleanup_old_items(directory)` | 디렉토리 내 초과 항목 삭제 |

#### `modules::hotkey`
| 메소드 | 설명 |
|--------|------|
| `setup_global_hotkey(app)` | 글로벌 단축키 등록 |
| `update_shortcut(app, shortcut)` | 단축키 변경 (해제 → 재등록) |
| `handle_shortcut(app, shortcut, event)` | 단축키 이벤트 핸들러 |
| `save_current_app()` | 현재 활성 앱 이름 저장 |
| `restore_prev_app_native()` | 이전 앱으로 포커스 복원 (NSWorkspace) |
| `toggle_main_window(app)` | 윈도우 토글 위임 |

#### `modules::window_manager`
| 메소드 | 설명 |
|--------|------|
| `toggle_main_window(app)` | 윈도우 표시/숨기기 + 위치 조정 |
| `set_window_state(visible)` | 윈도우 가시성 상태 설정 |
| `start_mouse_edge_monitor(app)` | 마우스 엣지 감지 스레드 시작 |
| `set_window_position(app)` | 초기 윈도우 위치 설정 |
| `update_mouse_edge_enabled(enabled)` | 엣지 감지 활성화 토글 |
| `start_height_resize(window)` | 높이 리사이즈 폴링 시작 |
| `stop_height_resize(window)` | 높이 리사이즈 중지 + 최종 높이 반환 |
| `get_active_screen_info()` | 마우스 위치 기반 활성 모니터 정보 |
| `get_mouse_location()` | 마우스 좌표 조회 (NSEvent) |

### 3.3 Frontend — 주요 함수 (App.svelte)

| 함수 | 설명 |
|------|------|
| `loadDirectories()` | 디렉토리 목록 로드 |
| `loadHistory()` | 히스토리 아이템 로드 |
| `showItemView(dirName)` | 디렉토리 내 아이템 뷰로 전환 |
| `showDirectoryView()` | 디렉토리 뷰로 복귀 |
| `showSettingsView()` | 설정 뷰로 전환 |
| `useItem(item)` | 아이템 붙여넣기 실행 |
| `createFolder(name)` | 폴더 생성 |
| `deleteDirectory(name)` | 폴더 삭제 (모달 확인) |
| `renameDirectory(oldName)` | 폴더 이름변경 (모달 입력) |
| `startEdit(item)` | 인라인 편집 시작 |
| `saveEdit()` | 편집 저장 |
| `createItem({content, memo})` | 수동 아이템 생성 |
| `deleteItem(id)` | 아이템 삭제 (모달 확인) |
| `handleKeyDown(event)` | 전역 키보드 이벤트 라우팅 |
| `startResize(e)` | 윈도우 높이 리사이즈 시작 |
| `stopResize()` | 리사이즈 종료 + 높이 저장 |
| `openModal(config)` / `closeModal()` | 모달 관리 |
| `resetAutoHideTimer()` / `clearAutoHideTimer()` | 자동 숨기기 타이머 |

### 3.4 Frontend — 컴포넌트 구조

```
App.svelte                  # 루트: 상태 관리, 키보드 라우팅, 뷰 전환
├── Header.svelte           # 타이틀 + 검색 입력 + 뒤로가기 + 설정 버튼
├── DirectoryView.svelte    # 폴더 목록, 새 폴더 생성, 컨텍스트 메뉴
│   └── ContextMenu.svelte  # 우클릭 메뉴 (Rename/Delete)
├── ItemView.svelte         # 아이템 목록, 새 아이템 생성
│   └── HistoryItem.svelte  # 개별 아이템 (선택/편집/액션 버튼)
├── SearchView.svelte       # 전역 검색 결과 (폴더+아이템)
│   └── HistoryItem.svelte
├── SettingsView.svelte     # 설정 화면 (단축키/토글들)
│   └── Toggle.svelte       # 토글 스위치 UI
├── Modal.svelte            # 확인/입력 모달
├── DetailModal.svelte      # 아이템 전체 내용 보기 모달
└── ui/
    ├── Button.svelte       # 버튼 컴포넌트
    ├── Input.svelte        # 입력 컴포넌트
    ├── Toggle.svelte       # 토글 스위치
    └── ContextMenu.svelte  # 우클릭 메뉴
```

---

## 4. 데이터 모델

### 4.1 DB 스키마

```sql
CREATE TABLE directories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE paste_sheets (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    content     TEXT NOT NULL,
    directory   TEXT NOT NULL,
    memo        TEXT,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (directory) REFERENCES directories(name)
);

CREATE TABLE settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

### 4.2 Rust 데이터 구조체

```rust
struct PasteItem {
    id: i64,
    content: String,
    directory: String,
    created_at: String,
    memo: Option<String>,
}

struct DirectoryInfo {
    name: String,
    count: i64,
}
```

### 4.3 Settings 키 목록

| Key | 값 | 설명 |
|-----|---|------|
| `mouse_edge_enabled` | `"true"/"false"` | 마우스 엣지 감지 |
| `auto_hide_enabled` | `"true"/"false"` | 자동 숨기기 |
| `auto_hide_timeout` | `"3"~"60"` | 자동 숨기기 시간(초) |
| `shortcut` | `"CommandOrControl+Shift+V"` | 글로벌 단축키 |
| `auto_start` | `"true"/"false"` | 자동 시작 |

---

## 5. 시퀀스 다이어그램

### 5.1 앱 초기화

```
┌──────┐     ┌───────┐     ┌────┐     ┌──────────┐     ┌─────────┐
│Tauri │     │Hotkey │     │ DB │     │Clipboard │     │WindowMgr│
└──┬───┘     └──┬────┘     └─┬──┘     └────┬─────┘     └────┬────┘
   │            │            │              │                │
   │──init_db()─────────────>│              │                │
   │            │            │──CREATE TABLEs                │
   │            │            │<─Ok──────────│                │
   │            │            │              │                │
   │──get_setting("auto_start")────────────>│                │
   │  (첫 실행이면 autostart 활성화)        │                │
   │            │            │              │                │
   │──get_setting("mouse_edge_enabled")────>│                │
   │──update_mouse_edge_enabled()──────────────────────────->│
   │            │            │              │                │
   │──TrayIconBuilder────────│              │                │
   │  (아이콘, 메뉴, 이벤트 설정)           │                │
   │            │            │              │                │
   │──monitor_clipboard()───────────────────>│               │
   │            │            │   (스레드 시작, 100ms 폴링)   │
   │            │            │              │                │
   │──setup_global_hotkey()─>│              │                │
   │  save_current_app()     │──get_setting("shortcut")──>  │
   │            │            │              │                │
   │──start_mouse_edge_monitor()────────────────────────────>│
   │            │            │    (스레드 시작, 100ms 폴링)  │
   │            │            │              │                │
   │──Frontend mount()       │              │                │
   │  ├─ localStorage 높이 복원             │                │
   │  ├─ listen("window-visible")           │                │
   │  ├─ listen("clipboard-updated")        │                │
   │  ├─ loadDirectories()   │              │                │
   │  └─ loadHistory()       │              │                │
```

### 5.2 클립보드 감지 → 저장

```
┌──────────┐     ┌────┐     ┌────────┐
│Clipboard │     │ DB │     │Frontend│
│ Monitor  │     │    │     │        │
└────┬─────┘     └─┬──┘     └───┬────┘
     │ (100ms 폴링)│            │
     │──get_clipboard_text()    │
     │  새 텍스트 감지          │
     │             │            │
     │──find_by_content()──────>│
     │             │            │
     │  [이미 존재]             │
     │──update_content()──────->│  (timestamp 갱신)
     │             │            │
     │  [새 내용]               │
     │──post_content()─────────>│
     │──cleanup_old_items()────>│  (>30개면 오래된 것 삭제)
     │             │            │
     │──emit("clipboard-updated")──────────>│
     │             │            │──loadDirectories()
     │             │            │──loadHistory()
```

### 5.3 아이템 붙여넣기

```
┌────────┐     ┌──────┐     ┌──────────┐     ┌──────┐     ┌─────────┐
│Frontend│     │Tauri │     │Clipboard │     │Hotkey│     │이전 앱  │
└───┬────┘     └──┬───┘     └────┬─────┘     └──┬───┘     └────┬────┘
    │             │              │               │              │
    │──useItem()  │              │               │              │
    │──toggle_main_window()────>│  (윈도우 숨기기)              │
    │  (50ms 대기)│              │               │              │
    │──paste_text(text)────────>│               │              │
    │             │──set_text()─>│  (클립보드에 복사)           │
    │             │              │               │              │
    │             │──restore_prev_app_native()──>│              │
    │             │              │   (80ms 대기) │──activate───>│
    │             │              │               │  (NSWorkspace)│
    │             │──restore_prev_app_native()──>│  (2차 복원)  │
    │             │              │   (50ms 대기) │              │
    │             │──Cmd+V 키 시뮬레이션 (enigo)               │
    │             │              │               │         [붙여넣기됨]
```

### 5.4 윈도우 토글 (단축키)

```
┌──────┐     ┌──────────┐     ┌────────┐
│Hotkey│     │WindowMgr │     │Frontend│
└──┬───┘     └────┬─────┘     └───┬────┘
   │              │               │
   │──handle_shortcut()           │
   │  save_current_app()          │
   │──toggle_main_window()──────->│
   │              │               │
   │  [숨겨진 상태]               │
   │  ├─ get_active_screen_info() │
   │  ├─ set_position(우측 끝)    │
   │  ├─ show() + set_focus()     │
   │  └─ emit("window-visible", true)─────>│
   │              │               │──loadDirectories()
   │              │               │──loadHistory()
   │              │               │──resetAutoHideTimer()
   │              │               │
   │  [보이는 상태]               │
   │  ├─ emit("window-visible", false)────>│
   │  ├─ (350ms 후 hide())       │──clearAutoHideTimer()
```

### 5.5 마우스 엣지 감지

```
┌──────────┐     ┌──────────┐     ┌────────┐
│Mouse Edge│     │WindowMgr │     │Frontend│
│ Monitor  │     │          │     │        │
└────┬─────┘     └────┬─────┘     └───┬────┘
     │ (100ms 폴링)   │              │
     │──get_mouse_location()         │
     │──get_active_screen_info()     │
     │                │              │
     │  [마우스 ≥ 우측끝-2px && 윈도우 숨김]
     │  ├─ set_position(우측 끝)     │
     │  ├─ show() + set_focus()      │
     │  ├─ auto_hide = true          │
     │  └─ emit("window-visible", true)──>│
     │                │              │
     │  [마우스 < 우측끝-윈도우폭 && auto_hide]
     │  ├─ emit("window-visible", false)─>│
     │  ├─ (150ms 후) hide()         │
```

### 5.6 키보드 네비게이션 플로우

```
┌──────────┐     ┌──────────────────────────────────┐
│ Keyboard │     │            App.svelte             │
│  Event   │     │  handleKeyDown()                  │
└────┬─────┘     └────────────┬─────────────────────┘
     │                        │
     │──keydown──────────────>│
     │                        │
     │  ┌─ Escape ────────────┤
     │  │  1. modalConfig.show → closeModal()
     │  │  2. detailItem      → closeDetail()
     │  │  3. editingId       → cancel edit
     │  │  4. settings view   → showDirectoryView()
     │  │  5. searchQuery     → clear search
     │  │  6. otherwise       → toggle_main_window()
     │  │
     │  ├─ ArrowUp/Down ─────┤
     │  │  selectedIndex 순환 이동
     │  │
     │  ├─ ArrowRight ────────┤
     │  │  directories → showItemView()
     │  │  items       → buttonFocusIndex++ (Paste→Edit→Delete)
     │  │
     │  ├─ ArrowLeft ─────────┤
     │  │  items (btnIdx>0) → buttonFocusIndex--
     │  │  items (btnIdx=0) → showDirectoryView()
     │  │
     │  ├─ Enter ─────────────┤
     │  │  directories  → showItemView()
     │  │  items        → executeSelectedAction()
     │  │  search+input → executeSelectedAction()
     │  │
     │  ├─ Space ─────────────┤
     │  │  items → handleView() (DetailModal)
     │  │
     │  ├─ Cmd+Backspace ─────┤
     │  │  → deleteDirectory() or deleteItem()
     │  │
     │  └─ 일반 문자 ─────────┤
     │     → header.focusSearch() (자동 검색 진입)
```

---

## 6. 데이터 플로우 다이어그램

### 6.1 전체 아키텍처

```
┌─────────────────────────────────────────────────────┐
│                    macOS / Windows                    │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ System       │  │ Global       │  │ Mouse     │  │
│  │ Clipboard    │  │ Shortcut     │  │ Position  │  │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘  │
└─────────┼─────────────────┼────────────────┼─────────┘
          │                 │                │
          ▼                 ▼                ▼
┌─────────────────── Rust Backend ─────────────────────┐
│                                                       │
│  ┌──────────────┐  ┌──────────┐  ┌────────────────┐  │
│  │  clipboard   │  │  hotkey  │  │ window_manager │  │
│  │  monitor     │  │  handler │  │  edge monitor  │  │
│  │  (thread)    │  │          │  │  (thread)      │  │
│  └──────┬───────┘  └────┬─────┘  └───────┬────────┘  │
│         │               │                │            │
│         ▼               ▼                ▼            │
│  ┌─────────────────────────────────────────────────┐  │
│  │              Tauri IPC Commands                  │  │
│  │  (17 commands: CRUD, paste, settings, window)   │  │
│  └──────────────────────┬──────────────────────────┘  │
│                         │                             │
│  ┌──────────────┐       │                             │
│  │   SQLite DB  │<──────┤                             │
│  │ directories  │       │                             │
│  │ paste_sheets │       │                             │
│  │ settings     │       │                             │
│  └──────────────┘       │                             │
└─────────────────────────┼─────────────────────────────┘
                          │ Tauri invoke() / emit()
                          ▼
┌─────────────────── Svelte Frontend ──────────────────┐
│                                                       │
│  ┌──────────────────────────────────────────────────┐ │
│  │                 App.svelte                        │ │
│  │  State: directories[], historyItems[],            │ │
│  │         currentView, searchQuery, selectedIndex   │ │
│  │                                                    │ │
│  │  ┌────────┐ ┌──────────┐ ┌────────┐ ┌──────────┐ │ │
│  │  │Header  │ │Directory │ │ItemView│ │SearchView│ │ │
│  │  │(search)│ │View      │ │        │ │          │ │ │
│  │  └────────┘ └──────────┘ └────────┘ └──────────┘ │ │
│  │                                                    │ │
│  │  ┌──────────┐ ┌────────────┐ ┌────────────────┐   │ │
│  │  │Settings  │ │DetailModal │ │ConfirmModal    │   │ │
│  │  │View      │ │            │ │                │   │ │
│  │  └──────────┘ └────────────┘ └────────────────┘   │ │
│  └──────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────┘
```

### 6.2 상태 전이도 (Frontend Views)

```
                    ┌─────────┐
         ┌─────────│ 앱 시작  │
         │         └─────────┘
         ▼
    ┌──────────┐  ArrowRight/Enter/Click  ┌──────────┐
    │Directory │ ───────────────────────> │  Item    │
    │  View    │ <─────────────────────── │  View    │
    └──────────┘  ArrowLeft/Back btn      └──────────┘
         │                                     │
         │ Settings btn                        │
         ▼                                     │
    ┌──────────┐                               │
    │ Settings │ <── ArrowLeft/Escape ─────────┘
    │  View    │                          (from settings)
    └──────────┘

    [어느 뷰에서든 타이핑 시]
         │
         ▼
    ┌──────────┐
    │ Search   │ ─── Escape/Clear ──> 이전 뷰 복귀
    │  View    │
    └──────────┘
```

### 6.3 Tauri 이벤트 흐름

```
Backend → Frontend (emit):
  "clipboard-updated"  →  loadDirectories() + loadHistory()
  "window-visible"     →  true: 데이터 로드 + 타이머 시작
                          false: 타이머 정지

Frontend → Backend (invoke):
  get_clipboard_history, get_directories     → 데이터 조회
  create/update/delete_history_item          → 아이템 CRUD
  create/rename/delete_directory             → 디렉토리 CRUD
  paste_text                                 → 붙여넣기 실행
  toggle_main_window                         → 윈도우 토글
  get_setting / update_setting               → 설정 R/W
  update_shortcut                            → 단축키 변경
  set_autostart / get_autostart              → 자동시작
  start_height_resize / stop_height_resize   → 리사이즈
```

---

## 7. 의존성 목록

### Rust (Cargo.toml)
| 크레이트 | 용도 |
|----------|------|
| `tauri` 2.9.4 | 앱 프레임워크 (tray-icon, macos-private-api) |
| `tauri-plugin-global-shortcut` | 글로벌 단축키 |
| `tauri-plugin-autostart` | 로그인 시 자동시작 |
| `tauri-plugin-log` | 로깅 (debug 빌드) |
| `rusqlite` (bundled) | SQLite DB |
| `arboard` | 시스템 클립보드 접근 |
| `enigo` | 키보드 입력 시뮬레이션 |
| `active-win-pos-rs` | 활성 윈도우 감지 |
| `cocoa` + `objc` | macOS 네이티브 API |
| `image` | 트레이 아이콘 로딩 |
| `dirs` | 시스템 디렉토리 경로 |
| `serde` + `serde_json` | 직렬화 |

### Frontend (package.json)
- Svelte 4 + Vite
- Tailwind CSS
- `@tauri-apps/api` (invoke, event, window, dpi)
