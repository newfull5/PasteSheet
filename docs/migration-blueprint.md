# PasteSheets Migration Blueprint

> **Source**: Tauri 2 (Rust + Svelte)
> **Target**: macOS Native (Swift / AppKit), 추후 Windows 확장
> **Architecture**: Clean Architecture (Data → Domain → Presentation)
> **이 문서의 목적**: Claude Code가 이 문서를 컨텍스트로 읽고 즉시 코딩에 착수할 수 있는 완전한 설계 명세

---

## 1. 전체 기능 목록 (Use Cases)

### UC-01: 클립보드 자동 감지 및 저장
- 시스템 클립보드를 100ms 간격으로 폴링
- 새 텍스트 감지 시 "Clipboard" 폴더에 자동 저장
- 동일 내용이 이미 존재하면 timestamp만 갱신 (중복 방지)
- 빈 문자열/공백만 있는 내용은 무시
- 폴더당 최대 30개 유지, 초과 시 가장 오래된 항목 삭제

### UC-02: 아이템 붙여넣기
- 선택한 아이템의 텍스트를 시스템 클립보드에 설정
- 이전 활성 앱으로 포커스 복원 (더블 복원 + 딜레이)
- Cmd+V 키 시뮬레이션으로 붙여넣기 실행

### UC-03: 히스토리 아이템 CRUD
- 전체 아이템 조회 (최신순 정렬)
- 수동 아이템 생성 (content + directory + memo)
- 아이템 수정 (content, directory, memo 변경, timestamp 갱신)
- 아이템 삭제

### UC-04: 디렉토리(폴더) 관리
- 디렉토리 목록 조회 (항목 수 포함, "Clipboard" 항상 첫 번째)
- 디렉토리 생성 (이름 trim, 빈 이름 거부)
- 디렉토리 이름변경 (트랜잭션: directories + paste_sheets 동시 갱신)
- 디렉토리 삭제 (하위 아이템 전부 삭제 후 디렉토리 삭제)
- "Clipboard" 폴더는 이름변경/삭제 불가

### UC-05: 전역 검색
- 검색어로 디렉토리명, 아이템 content, 아이템 memo 필터링
- 결과를 "Folders" 섹션 + "Items" 섹션으로 분리 표시
- 검색 중 키보드 네비게이션 유지

### UC-06: 글로벌 단축키
- 기본: Cmd+Shift+V
- 단축키 누르면 이전 앱 저장 → 윈도우 토글
- 사용자가 키 조합을 녹음 방식으로 커스터마이징 가능
- 변경 시 기존 단축키 해제 → 새 단축키 등록 → DB 저장

### UC-07: 윈도우 관리
- 화면 우측 끝에 고정 (활성 모니터 감지, 멀티모니터 대응)
- 토글: 숨김 → 위치 계산 → show + focus + 애니메이션 / 보임 → 애니메이션 → 350ms 후 hide
- 닫기 버튼 = 숨기기 (앱 종료 아님)
- 하단 드래그로 높이 조절 (300~1400px), 높이 로컬 저장/복원
- 폭 고정 380px, decorations 없음, transparent, alwaysOnTop

### UC-08: 마우스 엣지 감지
- 100ms 폴링으로 마우스 위치 확인
- 마우스가 화면 우측 끝 2px 이내 → 윈도우 자동 표시 (auto_hide 모드)
- 마우스가 윈도우 폭만큼 벗어나면 → 150ms 후 자동 숨기기
- 설정에서 on/off 가능

### UC-09: 자동 숨기기 (Auto-hide)
- 설정에서 활성화 시 비활성 타이머 시작
- 키보드/마우스 활동 시 타이머 리셋
- 타임아웃(3/5/10/30/60초) 도달 시 윈도우 숨기기

### UC-10: 시스템 트레이
- macOS 템플릿 아이콘 (Retina @2x 대응)
- 좌클릭: 윈도우 토글
- 우클릭 메뉴: Show App / Quit
- Dock에 표시 안 됨 (Accessory 정책)

### UC-11: 자동 시작 (Launch at Login)
- macOS LaunchAgent 기반
- 첫 실행 시 기본 활성화
- 설정에서 on/off 토글

### UC-12: 설정 관리
- key-value 기반 설정 저장/조회
- 설정 키: mouse_edge_enabled, auto_hide_enabled, auto_hide_timeout, shortcut, auto_start

### UC-13: 키보드 전용 네비게이션
- ↑/↓: 리스트 항목 이동 (순환)
- →: 폴더 진입 / 아이템 내 버튼 이동 (Paste→Edit→Delete)
- ←: 폴더로 복귀 / 버튼 역이동
- Enter: 실행 (폴더 열기, 버튼 실행)
- Space: 아이템 상세 보기 모달
- Cmd+Backspace: 삭제 (확인 모달)
- Escape: 모달→상세→편집→설정→검색→윈도우 순으로 닫기
- 아무 문자 입력: 자동 검색 진입

---

## 2. DB 스키마

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

### 초기 데이터
```sql
INSERT OR IGNORE INTO directories (name) VALUES ('Clipboard');
INSERT OR IGNORE INTO settings (key, value) VALUES ('mouse_edge_enabled', 'true');
```

### 마이그레이션 규칙
- `paste_sheets`에 `memo` 컬럼이 없으면 `ALTER TABLE paste_sheets ADD COLUMN memo TEXT`
- `paste_sheets`에 존재하는 directory 값을 `directories` 테이블에 자동 등록

---

## 3. DTO / Entity 정의

### 3.1 PasteItem

```
목적: 클립보드 히스토리 아이템 하나를 표현
사용처: DB 조회/저장, UI 리스트 표시, 붙여넣기 대상

필드:
  id          : Int64       (PK, auto-increment)
  content     : String      (필수, 클립보드 텍스트)
  directory   : String      (필수, 소속 폴더명, FK → directories.name)
  createdAt   : String      (ISO timestamp, DB DEFAULT)
  memo        : String?     (선택적 사용자 라벨)
```

### 3.2 DirectoryInfo

```
목적: 디렉토리와 그 안의 아이템 수를 표현
사용처: 디렉토리 목록 UI

필드:
  name  : String    (폴더명, unique)
  count : Int64     (해당 폴더의 아이템 수, LEFT JOIN 집계)
```

### 3.3 Settings (Key-Value)

```
목적: 앱 설정을 key-value로 저장
사용처: 모든 설정 읽기/쓰기

키 목록:
  "mouse_edge_enabled"  : "true" | "false"   (기본: "true")
  "auto_hide_enabled"   : "true" | "false"   (기본: "false")
  "auto_hide_timeout"   : "3"~"60"           (기본: "5")
  "shortcut"            : 단축키 문자열       (기본: "CommandOrControl+Shift+V")
  "auto_start"          : "true" | "false"   (기본: "true")
```

### 3.4 타입 매핑 (Rust → Swift)

| Rust | Swift |
|------|-------|
| `i64` | `Int64` |
| `String` | `String` |
| `Option<String>` | `String?` |
| `Vec<T>` | `[T]` |
| `bool` | `Bool` |
| `Result<T, E>` | `throws -> T` 또는 `Result<T, Error>` |

---

## 4. 아키텍처 및 폴더 구조

### 4.1 모노레포 루트

```
PasteSheets/
├── apps/                      # 플랫폼별 클라이언트 앱
│   ├── macos/                 # Swift / AppKit (Xcode 프로젝트)
│   │   └── CLAUDE.md          # macOS 앱 개발 가이드 (Claude용)
│   └── windows/               # C# / WPF 또는 WinUI 3 (추후)
│       └── CLAUDE.md          # Windows 앱 개발 가이드 (Claude용)
│
├── packages/                  # 공유 로직 및 스펙
│   ├── core-bridge/           # 플랫폼과 공유 로직을 연결하는 인터페이스 정의
│   └── schema/                # DB 스키마 정의 (SQL)
│
├── docs/                      # 설계 문서
│   ├── project-analysis.md    # 과거 프로젝트 전체 분석
│   ├── claude-reference.md    # Claude 컨텍스트 주입용 레퍼런스
│   └── migration-blueprint.md # 마이그레이션 설계서 (이 문서)
│
├── _deprecated/               # 기존 Tauri 코드 백업 (참조용)
└── CLAUDE.md                  # 프로젝트 루트 가이드
```

### 4.2 macOS 앱 내부 구조 (apps/macos/)

```
apps/macos/PasteSheets/
├── App/
│   ├── PasteSheetsApp.swift          # @main, NSApplication 설정
│   ├── AppDelegate.swift             # 트레이, Dock 숨기기, 라이프사이클
│   └── Constants.swift               # 상수 (폴링 간격, 윈도우 크기 등)
│
├── Data/
│   ├── Database/
│   │   ├── DatabaseManager.swift     # SQLite 연결, 초기화, 마이그레이션
│   │   └── DatabaseSchema.swift      # 테이블 생성 SQL
│   ├── DataSources/
│   │   ├── PasteItemDataSource.swift # paste_sheets CRUD
│   │   ├── DirectoryDataSource.swift # directories CRUD
│   │   └── SettingsDataSource.swift  # settings CRUD
│   └── DTOs/
│       ├── PasteItemDTO.swift        # DB row ↔ struct 매핑
│       └── DirectoryInfoDTO.swift
│
├── Domain/
│   ├── Entities/
│   │   ├── PasteItem.swift           # 비즈니스 엔티티
│   │   └── DirectoryInfo.swift
│   ├── Repositories/                 # 프로토콜 (인터페이스)
│   │   ├── PasteItemRepository.swift
│   │   ├── DirectoryRepository.swift
│   │   └── SettingsRepository.swift
│   └── UseCases/
│       ├── ClipboardMonitorUseCase.swift
│       ├── PasteTextUseCase.swift
│       ├── ManageItemsUseCase.swift
│       ├── ManageDirectoriesUseCase.swift
│       ├── SearchUseCase.swift
│       └── SettingsUseCase.swift
│
├── Presentation/
│   ├── ViewModels/
│   │   ├── AppViewModel.swift        # 전역 상태, 뷰 전환, 키보드 라우팅
│   │   ├── DirectoryViewModel.swift
│   │   ├── ItemViewModel.swift
│   │   ├── SearchViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/
│   │   ├── MainPanel.swift           # NSPanel 기반 메인 윈도우
│   │   ├── DirectoryListView.swift
│   │   ├── ItemListView.swift
│   │   ├── SearchResultView.swift
│   │   ├── SettingsView.swift
│   │   ├── DetailModalView.swift
│   │   └── ConfirmModalView.swift
│   └── Components/
│       ├── HeaderView.swift
│       ├── HistoryItemRow.swift
│       ├── DirectoryRow.swift
│       ├── ToggleRow.swift
│       └── ContextMenuBuilder.swift
│
├── Services/
│   ├── ClipboardService.swift        # NSPasteboard 폴링
│   ├── HotkeyService.swift           # CGEvent / MASShortcut 글로벌 단축키
│   ├── WindowPositionService.swift   # 화면 위치 계산, 멀티모니터
│   ├── MouseEdgeService.swift        # 마우스 엣지 감지
│   ├── KeySimulationService.swift    # CGEvent 키 시뮬레이션 (Cmd+V)
│   ├── PreviousAppService.swift      # NSWorkspace 이전 앱 저장/복원
│   └── AutoStartService.swift        # SMAppService / LaunchAgent
│
└── Resources/
    ├── Assets.xcassets
    │   └── TrayIcon (iconTemplate, iconTemplate@2x)
    └── Info.plist
```

---

## 5. 메소드 시그니처 전체 정의

### 5.1 Data Layer — DatabaseManager

```swift
class DatabaseManager {
    static let shared: DatabaseManager

    /// DB 파일 경로 (~Library/Application Support/paste_sheets.db)
    func databasePath() -> String

    /// DB 연결 + 테이블 생성 + 마이그레이션 실행
    /// 앱 시작 시 1회 호출
    func initialize() throws
}
```

### 5.2 Data Layer — PasteItemDataSource

```swift
protocol PasteItemDataSource {

    /// 전체 아이템 조회 (created_at DESC)
    func fetchAll() throws -> [PasteItemDTO]

    /// 아이템 삽입, 생성된 row ID 반환
    func insert(content: String, directory: String, memo: String?) throws -> Int64

    /// 아이템 갱신 (content, directory, memo, created_at = now)
    func update(id: Int64, content: String, directory: String, memo: String?) throws

    /// 아이템 삭제
    func delete(id: Int64) throws

    /// content + directory로 기존 아이템 검색 (중복 체크용)
    /// 반환: 일치하는 아이템 또는 nil
    func findByContent(_ content: String, directory: String) throws -> PasteItemDTO?

    /// 특정 디렉토리의 아이템 수 조회
    func countByDirectory(_ directory: String) throws -> Int64

    /// 특정 디렉토리에서 가장 오래된 항목부터 excess개 삭제
    func deleteOldest(directory: String, excess: Int64) throws
}
```

### 5.3 Data Layer — DirectoryDataSource

```swift
protocol DirectoryDataSource {

    /// 디렉토리 목록 + 아이템 수 (Clipboard 먼저, 나머지 created_at순)
    func fetchAll() throws -> [DirectoryInfoDTO]

    /// 디렉토리 생성, 생성된 row ID 반환
    func insert(name: String) throws -> Int64

    /// 디렉토리 이름변경 (directories + paste_sheets 동시, 트랜잭션)
    func rename(oldName: String, newName: String) throws

    /// 디렉토리 삭제 (하위 아이템 먼저 삭제, 그 다음 디렉토리 삭제)
    func delete(name: String) throws
}
```

### 5.4 Data Layer — SettingsDataSource

```swift
protocol SettingsDataSource {

    /// 설정값 조회 (없으면 nil)
    func get(key: String) throws -> String?

    /// 설정값 저장 (UPSERT)
    func set(key: String, value: String) throws
}
```

### 5.5 Domain Layer — Repository Protocols

```swift
protocol PasteItemRepository {
    func getAllItems() throws -> [PasteItem]
    func createItem(content: String, directory: String, memo: String?) throws -> Int64
    func updateItem(id: Int64, content: String, directory: String, memo: String?) throws
    func deleteItem(id: Int64) throws
    func findByContent(_ content: String, directory: String) throws -> PasteItem?
    func cleanupOldItems(directory: String, maxCount: Int64) throws
}

protocol DirectoryRepository {
    func getAllDirectories() throws -> [DirectoryInfo]
    func createDirectory(name: String) throws -> Int64
    func renameDirectory(oldName: String, newName: String) throws
    func deleteDirectory(name: String) throws
}

protocol SettingsRepository {
    func getSetting(key: String) throws -> String?
    func setSetting(key: String, value: String) throws
}
```

### 5.6 Domain Layer — Use Cases

```swift
class ClipboardMonitorUseCase {
    /// 의존성: PasteItemRepository, ClipboardService
    /// 100ms 폴링 타이머로 클립보드 감시 시작
    /// 새 텍스트 감지 시:
    ///   1. findByContent(text, "Clipboard")
    ///   2. 존재하면 updateItem (timestamp 갱신)
    ///   3. 없으면 createItem → cleanupOldItems("Clipboard", 30)
    ///   4. onChange 콜백 호출 (UI 갱신 트리거)
    func startMonitoring(onChange: @escaping () -> Void)
    func stopMonitoring()
}

class PasteTextUseCase {
    /// 의존성: ClipboardService, PreviousAppService, KeySimulationService
    /// 실행 순서:
    ///   1. ClipboardService.setText(text)
    ///   2. PreviousAppService.restorePreviousApp()
    ///   3. 80ms 대기
    ///   4. PreviousAppService.restorePreviousApp() (2차)
    ///   5. 50ms 대기
    ///   6. KeySimulationService.simulatePaste() (Cmd+V)
    func execute(text: String) throws
}

class ManageItemsUseCase {
    /// 의존성: PasteItemRepository
    func getAllItems() throws -> [PasteItem]
    func createItem(content: String, directory: String, memo: String?) throws -> Int64
    func updateItem(id: Int64, content: String, directory: String, memo: String?) throws
    func deleteItem(id: Int64) throws
}

class ManageDirectoriesUseCase {
    /// 의존성: DirectoryRepository
    ///
    /// 제약 조건:
    ///   - create: name.trimmed 비어있으면 에러
    ///   - rename: "Clipboard" → 에러, newName 비어있으면 에러
    ///   - delete: "Clipboard" → 에러
    func getAllDirectories() throws -> [DirectoryInfo]
    func createDirectory(name: String) throws -> Int64
    func renameDirectory(oldName: String, newName: String) throws
    func deleteDirectory(name: String) throws
}

class SearchUseCase {
    /// 의존성: PasteItemRepository, DirectoryRepository
    ///
    /// query로 필터링:
    ///   - directories: name.lowercased.contains(query)
    ///   - items: content.lowercased.contains(query) OR memo.lowercased.contains(query)
    func search(query: String, allItems: [PasteItem], allDirectories: [DirectoryInfo])
        -> (directories: [DirectoryInfo], items: [PasteItem])
}

class SettingsUseCase {
    /// 의존성: SettingsRepository, MouseEdgeService, AutoStartService
    ///
    /// getSetting/setSetting + 사이드이펙트:
    ///   - "mouse_edge_enabled" 변경 시 → MouseEdgeService.setEnabled()
    ///   - "auto_start" 변경 시 → AutoStartService.setEnabled()
    func getSetting(key: String) throws -> String?
    func setSetting(key: String, value: String) throws
    func setAutoStart(enabled: Bool) throws
    func isAutoStartEnabled() throws -> Bool
}
```

### 5.7 Services (macOS Native API 래퍼)

```swift
class ClipboardService {
    /// NSPasteboard.general 래핑
    func getText() -> String?
    func setText(_ text: String)

    /// changeCount 기반 변경 감지 (폴링용)
    func hasChanged(since lastChangeCount: Int) -> Bool
    func currentChangeCount() -> Int
}

class HotkeyService {
    /// 글로벌 단축키 등록/해제
    /// macOS: CGEvent tap 또는 MASShortcut/HotKey 라이브러리
    func register(shortcut: String, handler: @escaping () -> Void) throws
    func unregisterAll()
    func updateShortcut(_ newShortcut: String, handler: @escaping () -> Void) throws
}

class PreviousAppService {
    /// NSWorkspace.shared.runningApplications로 이전 앱 추적
    ///
    /// save: 현재 활성 앱 이름 저장 (자기 자신 제외)
    /// restore: NSRunningApplication.activate(options:) 호출
    func saveCurrentApp()
    func restorePreviousApp()
}

class KeySimulationService {
    /// CGEvent로 Cmd+V 키 시뮬레이션
    func simulatePaste() throws
}

class WindowPositionService {
    /// NSScreen.screens + NSEvent.mouseLocation로 활성 모니터 감지
    ///
    /// 반환: (x, y) — 화면 우측 끝에서 윈도우 폭만큼 뺀 x좌표, 화면 상단 y좌표
    func calculatePosition(windowWidth: CGFloat) -> NSPoint?

    /// 현재 마우스 위치 반환
    func mouseLocation() -> NSPoint
}

class MouseEdgeService {
    /// 100ms 폴링으로 마우스 엣지 감지
    ///
    /// 로직:
    ///   mouse.x >= screen.right - 2  AND  윈도우 숨김  → onEdgeReached()
    ///   mouse.x <  screen.right - windowWidth  AND  autoHide모드 → onEdgeLeft()
    var isEnabled: Bool
    func startMonitoring(
        windowWidth: CGFloat,
        onEdgeReached: @escaping () -> Void,
        onEdgeLeft: @escaping () -> Void
    )
    func stopMonitoring()
    func setEnabled(_ enabled: Bool)
}

class AutoStartService {
    /// SMAppService (macOS 13+) 또는 LaunchAgent plist
    func enable() throws
    func disable() throws
    func isEnabled() -> Bool
}
```

### 5.8 Presentation Layer — ViewModels

```swift
class AppViewModel: ObservableObject {
    // --- 상태 ---
    @Published var currentView: ViewType        // .directories | .items | .settings
    @Published var isWindowVisible: Bool
    @Published var searchQuery: String
    @Published var selectedIndex: Int
    @Published var directories: [DirectoryInfo]
    @Published var allItems: [PasteItem]
    @Published var currentDirectory: String      // 현재 선택된 폴더명
    @Published var editingItemId: Int64?
    @Published var modalConfig: ModalConfig?
    @Published var detailItem: PasteItem?

    // --- 의존성 ---
    // ManageItemsUseCase, ManageDirectoriesUseCase, SearchUseCase,
    // PasteTextUseCase, ClipboardMonitorUseCase, SettingsUseCase

    // --- 뷰 전환 ---
    func showDirectoryView()
    func showItemView(directoryName: String)
    func showSettingsView()

    // --- 데이터 로드 ---
    func loadDirectories() throws
    func loadHistory() throws
    func onWindowBecameVisible()      // loadDirectories + loadHistory
    func onClipboardUpdated()         // loadDirectories + loadHistory

    // --- 아이템 액션 ---
    func pasteItem(_ item: PasteItem) // toggle window → 50ms → PasteTextUseCase.execute
    func startEdit(_ item: PasteItem)
    func saveEdit(content: String, directory: String, memo: String?)
    func cancelEdit()
    func createItem(content: String, memo: String?)
    func deleteItem(id: Int64)        // 모달 확인 후 실행

    // --- 디렉토리 액션 ---
    func createDirectory(name: String)
    func renameDirectory(oldName: String)   // 모달 입력 후 실행
    func deleteDirectory(name: String)      // 모달 확인 후 실행

    // --- 검색 ---
    /// searchQuery가 변경될 때마다 호출
    /// SearchUseCase.search() 결과를 filteredDirectories + filteredItems에 반영
    var filteredDirectories: [DirectoryInfo]   // computed
    var filteredItems: [PasteItem]             // computed

    // --- 키보드 ---
    func handleKeyDown(event: NSEvent)
    /// 내부 로직:
    ///   Escape → 닫기 체인 (modal→detail→edit→settings→search→window)
    ///   ↑/↓ → selectedIndex 변경 (순환)
    ///   →   → 폴더 진입 or 버튼 포커스 이동
    ///   ←   → 폴더 복귀 or 버튼 역이동
    ///   Enter → 실행
    ///   Space → 상세 보기
    ///   Cmd+Backspace → 삭제
    ///   일반 문자 → 검색 진입

    // --- 윈도우 ---
    func toggleWindow()
    func onAutoHideTimeout()

    // --- Auto-hide 타이머 ---
    func resetAutoHideTimer()
    func clearAutoHideTimer()
}

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
    let onConfirm: (String?) -> Void  // input value 또는 nil
}
```

---

## 6. 메소드 간 데이터 흐름

### 6.1 앱 초기화

```
AppDelegate.applicationDidFinishLaunching()
  │
  ├─→ DatabaseManager.shared.initialize()
  │     └─→ CREATE TABLE (directories, paste_sheets, settings)
  │     └─→ 마이그레이션 (memo 컬럼 추가 등)
  │     └─→ INSERT OR IGNORE 기본 데이터
  │
  ├─→ SettingsUseCase.getSetting("auto_start")
  │     └─→ 첫 실행(nil)이면 AutoStartService.enable() + setSetting("auto_start","true")
  │
  ├─→ SettingsUseCase.getSetting("mouse_edge_enabled")
  │     └─→ MouseEdgeService.setEnabled(value == "true")
  │
  ├─→ NSStatusBar 트레이 아이콘 생성
  │     ├─ 좌클릭 → AppViewModel.toggleWindow()
  │     └─ 메뉴: Show → toggleWindow(), Quit → NSApp.terminate()
  │
  ├─→ NSApp.setActivationPolicy(.accessory)  // Dock 숨기기
  │
  ├─→ ClipboardMonitorUseCase.startMonitoring(onChange: viewModel.onClipboardUpdated)
  │
  ├─→ HotkeyService.register(shortcut, handler: {
  │       PreviousAppService.saveCurrentApp()
  │       AppViewModel.toggleWindow()
  │   })
  │
  └─→ MouseEdgeService.startMonitoring(
          windowWidth: 380,
          onEdgeReached: { viewModel.showWindow() },
          onEdgeLeft:    { viewModel.hideWindow() }
      )
```

### 6.2 클립보드 감지 → 저장

```
ClipboardMonitorUseCase (Timer 100ms)
  │
  ├─→ ClipboardService.hasChanged(since: lastChangeCount)
  │     └─ false → return (변화 없음)
  │
  ├─→ ClipboardService.getText()
  │     └─ nil 또는 공백 → return
  │
  ├─→ PasteItemRepository.findByContent(text, "Clipboard")
  │     ├─ Some(existing) → PasteItemRepository.updateItem(existing.id, ...)
  │     └─ nil → PasteItemRepository.createItem(text, "Clipboard", nil)
  │             └─→ PasteItemRepository.cleanupOldItems("Clipboard", maxCount: 30)
  │
  └─→ onChange() 콜백
        └─→ AppViewModel.onClipboardUpdated()
              ├─→ loadDirectories()
              └─→ loadHistory()
```

### 6.3 아이템 붙여넣기

```
AppViewModel.pasteItem(item)
  │
  ├─→ toggleWindow()  // 윈도우 숨기기
  │
  └─→ (50ms 딜레이 후)
        └─→ PasteTextUseCase.execute(item.content)
              │
              ├─→ ClipboardService.setText(item.content)
              ├─→ PreviousAppService.restorePreviousApp()
              ├─→ (80ms 대기)
              ├─→ PreviousAppService.restorePreviousApp()  // 2차
              ├─→ (50ms 대기)
              └─→ KeySimulationService.simulatePaste()     // Cmd+V
```

### 6.4 윈도우 토글

```
AppViewModel.toggleWindow()
  │
  ├─ [현재 보이는 상태]
  │   ├─→ isWindowVisible = false
  │   ├─→ clearAutoHideTimer()
  │   ├─→ 윈도우 애니메이션 (opacity→0, translateX→60)
  │   └─→ (350ms 후) NSPanel.orderOut()
  │
  └─ [현재 숨긴 상태]
      ├─→ WindowPositionService.calculatePosition(windowWidth: 380)
      ├─→ NSPanel.setFrameOrigin(position)
      ├─→ NSPanel.orderFront() + makeKey()
      ├─→ isWindowVisible = true
      ├─→ onWindowBecameVisible()
      │     ├─→ loadDirectories()
      │     └─→ loadHistory()
      └─→ resetAutoHideTimer() (auto_hide 활성 시)
```

### 6.5 키보드 이벤트 라우팅

```
NSEvent (keyDown) → AppViewModel.handleKeyDown(event)
  │
  ├─ [Escape]
  │   ├─ modalConfig != nil    → modalConfig = nil
  │   ├─ detailItem != nil     → detailItem = nil
  │   ├─ editingItemId != nil  → editingItemId = nil
  │   ├─ currentView == .settings → showDirectoryView()
  │   ├─ searchQuery.isNotEmpty → searchQuery = ""
  │   └─ otherwise             → toggleWindow()
  │
  ├─ [↑/↓]
  │   └─→ selectedIndex = (selectedIndex ± 1) % listCount  (순환)
  │
  ├─ [→]
  │   ├─ .directories → showItemView(selected directory)
  │   └─ .items       → buttonFocusIndex += 1  (max 2: Paste=0, Edit=1, Delete=2)
  │
  ├─ [←]
  │   ├─ .items, btnIdx > 0  → buttonFocusIndex -= 1
  │   ├─ .items, btnIdx == 0 → showDirectoryView()
  │   └─ .settings            → showDirectoryView()
  │
  ├─ [Enter]
  │   ├─ .directories → showItemView(selected)
  │   ├─ .items       → 현재 buttonFocusIndex에 따라 paste/edit/delete 실행
  │   └─ search mode  → 검색 결과에서 실행
  │
  ├─ [Space] (.items만)
  │   └─→ detailItem = selectedItem
  │
  ├─ [Cmd+Backspace]
  │   └─→ deleteItem(id) 또는 deleteDirectory(name) — 모달 확인
  │
  └─ [일반 문자]
      └─→ searchQuery에 추가 (자동 검색 진입)
```

### 6.6 설정 변경

```
SettingsView → SettingsUseCase.setSetting(key, value)
  │
  ├─→ SettingsDataSource.set(key, value)  // DB 저장
  │
  └─→ 사이드이펙트:
        ├─ key == "mouse_edge_enabled" → MouseEdgeService.setEnabled(value == "true")
        └─ key == "auto_start"         → AutoStartService.enable() 또는 .disable()

단축키 변경:
  HotkeyService.updateShortcut(newShortcut, handler)
    ├─→ unregisterAll()
    ├─→ register(newShortcut, handler)
    └─→ SettingsDataSource.set("shortcut", newShortcut)
```

### 6.7 마우스 엣지 감지

```
MouseEdgeService (Timer 100ms)
  │
  ├─ isEnabled == false → sleep(500ms), continue
  │
  ├─→ WindowPositionService.mouseLocation()
  ├─→ NSScreen.main (활성 스크린 정보)
  │
  ├─ [mouse.x >= screen.maxX - 2  AND  윈도우 숨김]
  │   └─→ onEdgeReached()
  │         ├─→ WindowPositionService.calculatePosition()
  │         ├─→ NSPanel.setFrameOrigin() + orderFront()
  │         ├─→ isWindowVisible = true, isAutoHideMode = true
  │         └─→ onWindowBecameVisible()
  │
  └─ [mouse.x < screen.maxX - windowWidth  AND  isAutoHideMode]
      └─→ onEdgeLeft()
            ├─→ isWindowVisible = false, isAutoHideMode = false
            ├─→ (150ms 후) NSPanel.orderOut()
```

---

## 7. macOS Native API 매핑 참조

| 기존 (Tauri/Rust) | macOS Native (Swift) |
|----|-----|
| `arboard::Clipboard` | `NSPasteboard.general` |
| `enigo` 키 시뮬레이션 | `CGEvent(keyboardEventSource:...)` |
| `active-win-pos-rs` | `NSWorkspace.shared.frontmostApplication` |
| `NSWorkspace` (objc) 앱 복원 | `NSRunningApplication.activate(options:)` |
| `NSEvent::mouseLocation` (objc) | `NSEvent.mouseLocation` (Swift 네이티브) |
| `NSScreen::screens` (objc) | `NSScreen.screens` |
| `tauri::WebviewWindow` | `NSPanel` (floating, non-activating) |
| `tauri-plugin-global-shortcut` | `CGEvent.tapCreate` 또는 `MASShortcut` / `HotKey` 라이브러리 |
| `tauri-plugin-autostart` (LaunchAgent) | `SMAppService.mainApp` (macOS 13+) |
| `rusqlite` | `SQLite.swift` 또는 `GRDB.swift` |
| `tauri::tray::TrayIconBuilder` | `NSStatusBar.system.statusItem(withLength:)` |
| `app.set_activation_policy(Accessory)` | `NSApp.setActivationPolicy(.accessory)` |
| `window.set_position(LogicalPosition)` | `NSPanel.setFrameOrigin(_:)` |
| `window.set_size(LogicalSize)` | `NSPanel.setContentSize(_:)` |
| `window.show() / hide()` | `NSPanel.orderFront(nil)` / `.orderOut(nil)` |
| CSS transition (opacity + translateX) | `NSAnimationContext.runAnimationGroup` 또는 SwiftUI `.transition` |
| `localStorage` (높이 저장) | `UserDefaults.standard` |

---

## 8. 비즈니스 룰 & 제약 조건

1. "Clipboard" 디렉토리는 이름변경/삭제 불가
2. 클립보드 자동 캡처 시 디렉토리당 최대 30개 (초과 시 oldest 삭제)
3. 동일 클립보드 내용은 중복 저장 안 함 (timestamp 갱신)
4. 빈 문자열/공백만 있는 클립보드 내용은 무시
5. 윈도우 폭 고정 380px, 높이 300~1400px (사용자 조절 가능)
6. 윈도우 위치: 항상 활성 모니터 우측 끝, 상단 정렬
7. 첫 실행 시 auto_start 기본 활성화
8. 마우스 엣지 감지 임계값: 우측 끝 2px (표시), 윈도우 폭 거리 (숨기기)
9. 붙여넣기 시 더블 포커스 복원 (80ms + 50ms 딜레이)
10. 클립보드 폴링 100ms, 마우스 엣지 폴링 100ms
11. 윈도우 숨기기 애니메이션 350ms 후 실제 hide
12. 디렉토리 이름변경은 트랜잭션 (directories + paste_sheets 동시 변경)
13. 닫기 버튼 = 숨기기 (앱 종료 아님)
14. Dock에 표시 안 됨 (Accessory 정책)

---

## 9. 상수 정의

```swift
enum Constants {
    static let clipboardPollingInterval: TimeInterval = 0.1     // 100ms
    static let mouseEdgePollingInterval: TimeInterval = 0.1     // 100ms
    static let mouseEdgeThreshold: CGFloat = 2.0                // px
    static let windowWidth: CGFloat = 380.0
    static let windowMinHeight: CGFloat = 300.0
    static let windowMaxHeight: CGFloat = 1400.0
    static let windowHideAnimationDelay: TimeInterval = 0.35    // 350ms
    static let pasteRestoreDelay1: TimeInterval = 0.08          // 80ms
    static let pasteRestoreDelay2: TimeInterval = 0.05          // 50ms
    static let pasteToggleDelay: TimeInterval = 0.05            // 50ms
    static let mouseEdgeAutoHideDelay: TimeInterval = 0.15      // 150ms
    static let maxItemsPerDirectory: Int64 = 30
    static let defaultDirectory = "Clipboard"
    static let defaultShortcut = "CommandOrControl+Shift+V"
    static let defaultAutoHideTimeout = 5                       // seconds
}
```
