# Windows 버전 격차 분석 (vs macOS v0.4.1)

> 기준: macOS 네이티브 앱 `apps/macos` (v0.4.1, Swift) ↔ Windows에서 동작하는 유일한 버전인
> Tauri 앱 `apps/windows/` (v0.2.0, Rust + Svelte — 구 `_deprecated/`에서 승격).
>
> 참고: 윈도우용 릴리스는 아직 한 번도 배포된 적이 없다 (전 릴리스가 macOS DMG뿐).
> Tauri 앱은 네이티브 마이그레이션 시점(v0.2.0)에 동결되어 그 이후의 기능/디자인 변화가 모두 누락됐다.

---

## A. 윈도우에서 아예 동작하지 않는 것 (Tauri 앱의 Windows 구현 구멍)

| # | 항목 | 현재 상태 | 근거 |
|---|------|----------|------|
| A-1 | **이전 앱 포커스 복원** | `restore_prev_app_native()`가 macOS 전용 — Windows에서는 빈 함수(no-op). 붙여넣기 키 입력(Ctrl+V)이 엉뚱한 창으로 들어감. **치명적** | `hotkey.rs:49-78` |
| A-2 | **마우스 엣지 피크** | 모니터 스레드 자체가 `#[cfg(macos)]`로만 생성. `get_mouse_location()` Windows 구현은 `None` 반환 스텁 | `window_manager.rs:76-83, 239-242` |
| A-3 | **표시 시 활성 모니터 우상단 재배치** | toggle-show의 재배치가 macOS 전용. 초기 배치도 첫 번째 모니터 + 잘못된 폭 상수(410, 실제 380) 사용 | `window_manager.rs:41-60, 109-119` |
| A-4 | **세로 드래그 리사이즈** | `start_height_resize` 본문이 macOS 전용 — Windows에서 no-op | `window_manager.rs:252-287` |
| A-5 | **작업표시줄 숨김** | macOS는 Dock 숨김(`ActivationPolicy::Accessory`), Windows는 `skipTaskbar` 미설정 → 작업표시줄에 노출 | `lib.rs:132-133`, `tauri.conf.json` |
| A-6 | **트레이 아이콘** | Windows는 기본 윈도우 아이콘 사용 (macOS는 전용 템플릿 아이콘) | `lib.rs:172-173` |
| A-7 | **폭 상수 버그** | Rust 쪽 fallback 폭이 410.0으로 하드코딩 (창 실제 폭 380) — 4개소 | `window_manager.rs:55, 102, 114, 154` |

## B. 플랫폼 무관하게 Tauri 앱에 없는 기능 (mac v0.4.1 대비 누락)

| # | 항목 | macOS v0.4.1 | Tauri v0.2.0 |
|---|------|--------------|--------------|
| B-1 | **자동 업데이트** | Sparkle 2 (appcast, 자동 체크 토글, Check Now 버튼) | 전무 — updater 플러그인 없음 |
| B-2 | **Launch at Login 설정 UI** | Settings > General 토글 | 백엔드 커맨드(`set_autostart`/`get_autostart`)만 있고 UI 없음 |
| B-3 | **Settings > Updates 그룹** | "Automatic Updates" 토글 + "Check for Updates / Check Now" | 없음 |
| B-4 | **버전 표기** | 번들에서 동적으로 읽음 (0.4.1) | `"0.1.0"` 하드코딩 (앱 버전 0.2.0과도 불일치) | 
| B-5 | **트레이 좌클릭 시 previous app 저장** | 좌클릭 → `saveCurrentApp()` → toggle | 좌클릭 → toggle만 (저장 안 함 → 트레이로 열면 포커스 복원 부정확) |
| B-6 | **표시 시 전체 가시 높이 스냅** | 매 표시마다 우측 끝 + 가시영역 전체 높이로 스냅 | 저장된 높이(기본 800) 그대로, 상단 우측 배치 |
| B-7 | **클립보드 캡처 상한 정책** | 30개 고정 (`maxItemsPerDirectory = 30`) | 기본 50 + Storage 설정 UI (30/50/100/200/∞) — mac에는 없는 구성 |

## C. 디자인 차이 (mac 기준으로 통일 필요)

| # | 항목 | macOS v0.4.1 | Tauri v0.2.0 |
|---|------|--------------|--------------|
| C-1 | 창 모서리/보더 | 4면 라운드 16pt + 1pt `white@0.10` 전체 보더, 시스템 그림자 | 좌측만 라운드 16px, 좌/상/하 보더만, CSS 그림자 `-4px 0 15px` |
| C-2 | 표시/숨김 애니메이션 | 표시 즉시, 숨김 0.35s 알파 페이드 | 표시/숨김 모두 slide(translateX 60px)+fade |
| C-3 | New Folder / New Item 행 | 라운드 6 **dashed** 보더(`white@0.05`, dash[5]) 박스 | `border-top` 1px solid + margin-top 12 스타일 |
| C-4 | 타임스탬프 | ISO 파싱 실패 시 raw DB 문자열 (`YYYY-MM-DD HH:MM:SS`) 표시 | `toLocaleString()` 포맷 |
| C-5 | 확인 모달 | maxWidth 340, backdrop blur 없음 | max-w-sm(384px), `backdrop-blur-sm` |
| C-6 | 헤더 여백 | 패딩 h16/t16/b12 + `Divider().opacity(0.1)` | margin-bottom 20px, min-height 40px, divider 없음 |
| C-7 | 선택 내용 표시 | 선택 시 lineLimit 15 (스크롤 없음) | max-height 350px 스크롤 |
| C-8 | 행 hover 효과 | 없음 (키보드 중심) | `rgba(255,255,255,0.05)` hover + border-bottom |
| C-9 | Delete 버튼 색 | `#FF4444` | hover/active `#ff5555` |
| C-10 | 설정 그룹 구성 | Shortcut / General(토글 3개) / Updates / Information | Shortcut / General(토글 2개) / **Storage** / Information |
| C-11 | 빈 검색 결과 여백 | top padding 60 | padding 60px 0 (동일) — 항목별 미세 차이는 구현 시 대조 |

## D. Tauri 쪽이 오히려 앞서는 것 (mac에 없는 동작)

| # | 항목 | 비고 |
|---|------|------|
| D-1 | **작동하는 단축키 레코더** | mac은 비주얼만 있고 실제 재바인딩 미구현. Tauri는 capture→`update_shortcut` 실제 동작 |
| D-2 | 모달에서 Enter 확인 / ←→ 버튼 포커스 이동 | mac은 모달 버튼이 마우스 전용 |
| D-3 | Enter로 New Folder/New Item 생성 시작 | mac은 마우스 클릭 전용 |
| D-4 | max items 설정 UI | mac은 30 고정 |

**처리 방침**: 룩앤필·기능 구성은 mac 기준으로 통일(C, B 적용. Storage 그룹 제거, 30 고정).
단, mac 쪽 명백한 미구현/버그(D-1 레코더, D-2 Enter 확인)는 윈도우에 일부러 복제하지 않고 유지한다.
mac 쪽도 D-1, D-2를 구현해서 맞추는 것이 최종 목표 상태.

## 구현 계획 (develop 기반, PR 하나씩)

1. **PR-1 (구조)** — 이 PR: `_deprecated/` → `apps/windows/`로 이동. Tauri 앱을 공식 Windows 앱으로 승격.
2. **PR-2 (A: Windows 네이티브 구멍)**: SetForegroundWindow 포커스 복원, GetCursorPos/모니터 API로 엣지 피크, 표시 시 재배치, 세로 리사이즈, skipTaskbar, 트레이 아이콘, 410→380.
3. **PR-3 (B: 기능 패리티)**: Launch at Login 토글 UI, Updates 그룹(+동적 버전), 트레이 좌클릭 prev-app 저장, 전체 높이 스냅, 캡처 상한 30 통일.
4. **PR-4 (C: 디자인 패리티)**: 창 chrome, 애니메이션, dashed 행, 타임스탬프, 모달 폭 등 mac과 픽셀 단위 일치.
5. **PR-5 (자동 업데이트)**: `tauri-plugin-updater` + GitHub Releases `latest.json`. **서명 키 생성 필요(사용자 작업) — 키 없으면 스캐폴드+문서까지만.**

검증: `cargo check`(+`--target x86_64-pc-windows-msvc`로 Windows 경로 타입체크), `npm run build`, macOS에서 `tauri dev`로 UI 대조.
