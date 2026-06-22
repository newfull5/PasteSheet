# PasteSheets Windows — 작업 목록 (파리티 TODO · 결함 · 기능 TC)

> 목적: macOS에서 완료한 UI 리디자인 + 버그픽스를 **Windows(C#/.NET WPF, `apps/windows/PasteSheet`)** 에 파리티로 반영하고 검증.
> macOS 기준 자료: `apps/macos/docs/ui-redesign-spec.md`, `apps/macos/docs/ui-mockups/index.html`, `apps/macos/docs/qa-test-cases.md`. 커밋 `a577429`, `bedf437`.
> Windows 핵심 파일(모놀리식): `Presentation/MainWindow.xaml`(UI 전체), `Presentation/AppViewModel.cs`(상태/키), `App/Constants.cs`, `Services/*`.
> 각 항목 분류 — 🎨 시각 / ⚙️ 동작 / 🐞 결함. 키 바인딩은 macOS(⌘) → Windows(Ctrl)로 매핑, 실제 값은 구현 확인.

---

## 📊 Gap 분석 결과 (2026-06-22, 코드 대조)

> 실제 Windows 코드(`MainWindow.xaml` 788줄, `AppViewModel.cs` 766줄, Services, Constants) 대조 결과.
> ⚠️ **이 Mac에선 빌드 불가** (dotnet 미설치 + `net8.0-windows`/WPF = Windows 전용). 검증은 CI 또는 Windows 머신 필요.

### ⚙️ 동작/결함 — 절반은 이미 됨 (호재)
- ✅ **이미 DONE**: W-14/DW-08 삭제 Enter=확정 · W-16/DW-01 삭제 즉시 갱신(ObservableCollection, SwiftUI 식별 버그 없음) · W-20/DW-02 타임스탬프 파싱(`RowItem.DateDisplay` TryParse+ToLocalTime)
- 🟡 **부분(DIFF)**: W-17/DW-07 붙여넣기 — settle(15ms)+적응형 폴링 **있음**, 단 **마우스엣지 경로에서 직전창 저장 누락**(`ShowWindowFromEdge`에 `SaveForegroundBeforeShow` 없음)
- ❌ **TODO(작고 안전, macOS 미러)**: W-18/DW-03 Ctrl+N 핸들러 없음 · W-19/DW-04 auto-hide 가드 없음(`ResetAutoHideTimer`에 modal/detail/edit/create 체크 X) · W-15/DW-06 삭제 후 포커스 유지(lastContentIndex 클램프 없음, New 행으로 빠짐) · W-21/DW-05 `SaveEdit` 빈내용 가드 없음(편집 시 빈 저장) · W-22 새폼 CONTENT 포커스(XAML 필드 순서 확인 필요)

### 🎨 시각 — 거의 전부 TODO
- ❌ **W-01 토큰**: 색 토큰 0개, **네온 #DCDC57이 12곳** 여전히 사용(L30 Accent정의, 토글 L117, 선택 L321, 기어 L298, 편집/새폼 테두리 6곳 등) + 하드코딩 hex 다수
- ❌ **W-06 검색 UI**: 투명 오버레이라 **입력칸이 안 보임** (macOS와 동일 문제) — 결과카운트·섹션·매치칩·소스배지 전부 없음
- ❌ **W-05**: Delete가 **텍스트 버튼**(휴지통 아이콘 아님), 행 구분선 없음
- 🟡 **W-07~W-12 DIFF**: 화면 골격은 있으나 색·반경·정렬이 구버전 (selection bar 4px→3px, 폴더 푸터 없음, Detail 메타푸터 없음, 삭제 미리보기 없음, 폼 라벨/순서/정렬 다름, 헤더 깜빡커서+골드 타이틀)
- ✅ **W-13 패널 외곽**: DONE (radius·테두리·패딩 일치)
- ❌ **W-23/24/25**: 힌트푸터·빈상태·호버/포커스 전부 없음

### 권장 순서
1. **동작 quick-win** (작고 안전, macOS 미러): Ctrl+N · 빈저장 가드 · auto-hide 가드 · 삭제 포커스 · 마우스엣지 직전창 저장 → AppViewModel.cs/Services 소규모 편집
2. **시각**: W-01 토큰부터 → 화면별. (단 빌드/렌더 검증이 안 되므로 Windows 환경에서 진행 권장)

### ✅ 적용됨 (2026-06-22 · ⚠️ 빌드/동작 검증 대기 — Mac에서 빌드 불가)
- **W-18** Ctrl+N → `AppViewModel.HandleKey` (items→새 아이템 / 루트→새 폴더)
- **W-19/DW-04** auto-hide 가드 → `ResetAutoHideTimer` Tick에 `HasModal/HasDetail/IsEditing/IsCreatingNew` 체크
- **W-15/DW-06** 삭제 후 포커스 유지 → `LastContentIndex` 추가 + `DeleteItem`/`DeleteDirectory`에서 clamp
- **W-21/DW-05** `SaveEdit` 빈내용 가드 (편집 폼 유지)
- **W-17/DW-07** 마우스엣지 진입 시 `SaveForegroundBeforeShow()` → `App.xaml.cs` 엣지 콜백
- **남음**: W-22(새폼 CONTENT 포커스 — XAML 필드 순서 확인 필요), 삭제 다이얼로그 제목 소문자(W-09 시각 패스에 포함)

---

## Part 1 — TODO: macOS 파리티 포팅

### A. 토대 (토큰 / 공용 컴포넌트)
- [ ] **W-01** 🎨 디자인 토큰 중앙화 — 네온 `#DCDC57` 폐기 → 차분한 골드 `#C7CA46`. accentPrimary·textPrimary/Secondary/Tertiary·surface·panelBg·neutralBorder·divider·danger·dangerText·focusBorder. (WPF `ResourceDictionary` 또는 `Constants.cs` — 현재 색 토큰 없음)
- [ ] **W-02** 🎨 ActionButton 3종 스타일 (goldPrimary / neutralSecondary / quietDanger) — WPF `Style`/`ControlTemplate`
- [ ] **W-03** 🎨 SelectionBar (차분한 골드 좌측 바, 글로우 없음)
- [ ] **W-04** 🎨 "화면당 골드 주요 액션 1개" 규칙 전역 적용

### B. 화면별 시각
- [ ] **W-05** 🎨 아이템 목록: 선택=골드 바+surface 틴트(글로우 X) · Paste 골드 / Edit 아웃라인 / **Delete=조용한 휴지통 아이콘**(우측, 호버/포커스 시 빨강) · 비선택 행 구분선 · New item 점선
- [ ] **W-06** 🎨 검색: **실제 입력 박스**(돋보기+박스+포커스 테두리+placeholder) · "N results for …" 카운트 · "ITEMS (N)" · 매치 **골드 칩** 하이라이트(네온 X) · 소스 배지+점
- [ ] **W-07** 🎨 루트 폴더 목록: 폴더 아이콘 · 카운트 차분 · 선택 바 풀하이트 · **New folder 하단 고정** · 푸터 "N folders · M items"
- [ ] **W-08** 🎨 Detail 모달: 중립 "Detail" 타이틀 · Copy=골드+아이콘 · Close 중립 · 헤더 surface · **메타 푸터(날짜·글자수)** · scrim 0.55 · radius 12
- [ ] **W-09** 🎨 삭제 다이얼로그: 중립 제목+휴지통 "Delete item" · **삭제 대상 미리보기 블록** · "permanently deleted" 문구 · [Cancel][Delete ↵] · 글로우 X
- [ ] **W-10** 🎨 설정: ON 토글 차분한 골드 · 섹션 라벨 대비↑ · 카드 surface+테두리+radius12 · 세그먼트 선택칩 골드틴트+semibold · 키캡 스타일
- [ ] **W-11** 🎨 편집/새 아이템 폼: **CONTENT / MEMO·optional 라벨** · 우측 정렬 [Cancel][Save] · 내용 필드 먼저
- [ ] **W-12** 🎨 헤더: 타이틀 중립(골드 X) · 정지 상태 깜빡 커서 제거 · 뒤로/톱니 중립
- [ ] **W-13** 🎨 패널 외곽: 모서리 반경 12 토큰 · 테두리 neutralBorder 토큰
- [ ] **W-23** 🎨 **힌트/void 필러**: 아이템 목록 하단 단축키 힌트("↵ paste · Ctrl+N new · 삭제") + 목록이 짧을 때 "You're all caught up" 안내로 빈 공간 채우기 (mockup §2.3)
- [ ] **W-24** 🎨 **빈 상태(empty states)**: 검색 결과 없음("No matches" + 돋보기 + "Nothing found for …") · 빈 폴더("No items found …") · 빈 루트(폴더 0개) 안내
- [ ] **W-25** 🎨 **호버/포커스 상태 + placeholder**: 행 hover 틴트 · 키보드 포커스 링(focusBorder) · 입력 placeholder("Add a note…", "Search clipboard…")

### C. 동작 / 키보드
- [ ] **W-14** ⚙️ 삭제 확인: Enter=삭제 처리(키 라우팅) — *(macOS 결정: 파괴적이지만 Enter=실행 유지)*
- [ ] **W-15** ⚙️ 삭제 후 **포커스 유지**(lastContentIndex 클램프) — 아이템+폴더 양쪽
- [ ] **W-16** ⚙️ 삭제 시 **목록 즉시 갱신** (정체성/리바인딩, 검색결과 재적용)
- [ ] **W-17** ⚙️ **간헐 붙여넣기 실패** 수정 — 포커스 복원 후 settle 지연 + 마우스엣지 진입 시 직전 창 저장
- [ ] **W-18** ⚙️ **Ctrl+N** → 새 아이템(폴더 안) / 새 폴더(루트)
- [ ] **W-19** ⚙️ auto-hide 차단: 모달/상세/편집/생성 중엔 자동 숨김 안 됨
- [ ] **W-20** ⚙️ 타임스탬프 SQLite 형식(`yyyy-MM-dd HH:mm:ss` UTC) 파싱 → 로컬 짧은 형식
- [ ] **W-21** ⚙️ 빈 내용 Save → 폼 유지(입력 보존)
- [ ] **W-22** ⚙️ 새 아이템 폼 진입 시 **CONTENT(내용) 포커스**

---

## Part 2 — 결함 점검 (macOS에서 겪고 고친 것 → Windows 동일 여부 확인)

> 이 결함들은 동일 설계 포팅이라 Windows에도 잠재할 가능성이 높음. "재현되는지 확인 → 같으면 수정".

- [ ] **DW-01** 🐞 **삭제 후 화면 즉시 반영 안 됨 / 멈춘 듯** — macOS 원인: 리스트 항목을 위치 인덱스로 식별(SwiftUI `.id(index)`)해 삭제 시 diff 꼬임. Windows 확인: `ItemsControl`/`ListBox` 항목 키가 **고유 id 기반**인지, 삭제 후 컬렉션이 즉시 갱신되는지. (W-16)
- [ ] **DW-02** 🐞 **타임스탬프가 원시 문자열로 표시** — macOS 원인: ISO8601 파서가 SQLite `CURRENT_TIMESTAMP`(`yyyy-MM-dd HH:mm:ss`, UTC)를 못 읽어 raw fallback. Windows 확인: `DateTime.Parse`/포맷이 SQLite 형식·UTC→로컬을 처리하는지. (W-20)
- [ ] **DW-03** 🐞 **단축키 힌트와 실제 동작 불일치(⌘N/Ctrl+N)** — macOS: 힌트엔 있으나 핸들러 없었음. Windows 확인: 푸터/툴팁의 단축키가 실제 `AppViewModel` 키 핸들러와 일치하는지. (W-18)
- [ ] **DW-04** 🐞 **상세/모달/편집 중 auto-hide가 닫아버림** — macOS: 타이머 가드가 일부 상태만 확인. Windows 확인: `MouseEdgeService`/auto-hide 타이머가 모달·상세·편집·생성 상태에서 차단되는지. (W-19)
- [ ] **DW-05** 🐞 **빈 내용 Save 시 폼 닫히고 입력 손실** — Windows 확인: Save/단축키 저장 경로에 빈 내용 guard. (W-21)
- [ ] **DW-06** 🐞 **마지막 항목 삭제 시 선택 포커스 사라짐** — macOS: selectedIndex가 맨 아래 New 행으로. Windows 확인: 삭제 후 선택이 실제 콘텐츠 행에 머무는지. (W-15)
- [ ] **DW-07** 🐞 **간헐적 붙여넣기 실패(다시 하면 됨)** — macOS 원인: 대상 앱이 frontmost 된 직후 키윈도우 준비 전 Cmd+V가 드롭. Windows 확인: `ForegroundWindowService` 복원 후 `KeySimulationService`(Ctrl+V) 사이 **settle/대기**가 있는지, 마우스엣지로 열 때 직전 창 저장하는지. (W-17)
- [ ] **DW-08** 🐞 **삭제 확인 Enter 동작** — macOS: 사용자 요청으로 Enter=삭제 유지(취소 아님). Windows 확인: 다이얼로그 Enter가 삭제를 실행하는지(또는 원하는 동작인지).
- [ ] **DW-09** 🐞 **검색 입력 UI 부재** — macOS: 타이틀 뒤 투명 텍스트필드라 입력칸이 안 보였음. Windows 확인: 검색이 **명시적 입력 박스**로 보이는지. (W-06)

---

## Part 3 — 기능 TC (Windows 수동 체크리스트)

> macOS `qa-test-cases.md`의 상태머신을 Windows로 적응. 키는 Windows 기준(Ctrl), 실제 바인딩은 구현 대조.
> 각 상태 진입 후 이벤트별 결과를 확인.

### 라이프사이클
- [ ] **T-LC-01** 전역 핫키(예: Ctrl+Shift+V) → 패널 표시 / 다시 → 숨김
- [ ] **T-LC-02** 트레이 아이콘 좌클릭 표시 · 우클릭 메뉴(Show/Quit)
- [ ] **T-LC-03** Auto-hide ON: 방치 → 자동 숨김 / OFF: 유지
- [ ] **T-LC-04** Mouse Edge ON: 우측 끝 → 슬라이드 인
- [ ] **T-LC-05** 재실행 시 트레이 전용(작업표시줄 미표시 등 Windows 관례)

### 루트 폴더 목록
- [ ] **T-FD-01** 폴더 아이콘 + 이름 + 카운트, 선택=골드 바+틴트
- [ ] **T-FD-02** ↑↓ 선택 이동, Enter 폴더 진입
- [ ] **T-FD-03** New folder 하단 고정 + "N folders · M items" 푸터
- [ ] **T-FD-04** New folder 생성/취소(Esc), 우클릭 Rename/Delete
- [ ] **T-FD-05** 폴더 삭제 → 확인 다이얼로그 → 삭제 후 **선택 유지**

### 폴더 아이템 목록
- [ ] **T-IT-01** 선택 카드: 내용·타임스탬프(짧은 형식)·Paste(골드)/Edit/🗑
- [ ] **T-IT-02** 🗑 호버 시 빨강 강조 · 비선택 행 구분선
- [ ] **T-IT-03** ←/→ 버튼 포커스 이동(Paste↔Edit↔Delete) — *Windows 키 확인*
- [ ] **T-IT-04** 하단 단축키 힌트(실제 동작과 일치)
- [ ] **T-IT-05** 빈 폴더 안내 문구

### 붙여넣기
- [ ] **T-PS-01** 아이템 Paste/Enter → 패널 닫힘 + 직전 창에 붙여넣기 + 포커스 복원
- [ ] **T-PS-02** 연속 여러 번 Paste → **매번 성공**(간헐 실패 없음) ← DW-07
- [ ] **T-PS-03** 마우스엣지로 열고 Paste → 올바른 창에 붙음 ← W-17

### 편집 / 새 아이템
- [ ] **T-ED-01** Edit → CONTENT/MEMO 라벨 + 우측 [Cancel][Save] · 저장/취소
- [ ] **T-NW-01** New item → 폼 열림 + **커서 CONTENT** · Ctrl+N도 동일 ← W-18/W-22
- [ ] **T-NW-02** 빈 내용 Save → 저장 안 되고 폼 유지 ← W-21

### 검색
- [ ] **T-SR-01** 입력 시작 → 검색 박스 + "N results" + "ITEMS (N)"
- [ ] **T-SR-02** 매치 **골드 칩** 하이라이트 · 소스 배지+점
- [ ] **T-SR-03** 결과에서 Paste/Edit/Delete, 삭제 시 즉시 사라짐
- [ ] **T-SR-04** 매치 없음 → 빈 상태("No matches …") · Esc 검색 종료

### 상세
- [ ] **T-DT-01** Space/더블클릭 → Detail 모달(중립 타이틀·골드 Copy·메타 푸터)
- [ ] **T-DT-02** Copy 동작 · 본문 선택 · Esc/X/배경 닫기
- [ ] **T-DT-03** 상세 띄운 채 방치 → auto-hide로 안 닫힘 ← W-19

### 삭제 다이얼로그
- [ ] **T-DL-01** 미리보기 블록 + [Cancel][Delete ↵]
- [ ] **T-DL-02** Enter=삭제(즉시) · Cancel/Esc/배경=취소
- [ ] **T-DL-03** 가운데 항목 삭제 → 그 항목만, 즉시 갱신 ← DW-01

### 설정
- [ ] **T-ST-01** 진입/복귀 · 토글 ON=차분한 골드 · 세그먼트 선택칩
- [ ] **T-ST-02** Launch at startup / Mouse Edge / Auto-hide / Updates
- [ ] **T-ST-03** 버전·개발자 정보 · 네온 노랑 미사용

### 클립보드 모니터링
- [ ] **T-CB-01** 다른 앱에서 복사 → Clipboard 폴더 최상단에 추가

### 키보드 종합
- [ ] **T-KB-01** ↑↓ 이동 · Enter 진입/액션 · Esc 단계적 닫힘
- [ ] **T-KB-02** Ctrl+N 새 항목 · Delete/Ctrl+Backspace 삭제(Windows 키 확인) · Space 상세

---

## 다음 단계
1. Part 2(결함)·Part 1(파리티)을 **현재 Windows 코드와 대조** → "이미 됨 / 포팅 필요 / 다름" 분류
2. 토대(W-01~04)부터 적용 → 화면별 시각 → 동작/결함
3. 빌드(.NET) + Part 3 기능 TC로 검증, macOS와 파리티 QA
