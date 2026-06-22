# PasteSheets Windows — 요소 단위 디자인 스펙 (granular)

> `windows-parity-todo.md`의 시각 항목(W-01~W-13, W-23~W-25)을 **요소 하나하나**로 분해.
> 기준: macOS `ui-redesign-spec.md` 토큰 + `ui-mockups/index.html` 개선안 + 구현된 0.6.0 코드.
> px는 macOS 기준 가이드(Windows DPI는 환산). **핵심은 색 토큰·반경·두께·구조**. 각 `[ ]` = 포팅/확인 단위.

## 0. 토큰 (WPF 리소스로 정의 — 모든 색은 이 토큰만 사용)
- [ ] `accentPrimary` **#C7CA46** (차분한 골드, 화면당 1개 주요 액션 전용) — 네온 #DCDC57 폐기
- [ ] `focusBorder` **#B9BC44** (포커스 테두리/링)
- [ ] `textPrimary` **#EDEDE8** · `textSecondary` **#9A9A92** · `textTertiary` **#7C7C74**
- [ ] `surface` **#232320** (카드/입력/선택 틴트/키캡) · `panelBg` **#1B1B19**
- [ ] `neutralBorder` **#FFFFFF @10%** · `divider` **#FFFFFF @6%**
- [ ] `danger` **#E24B4A** (채움 파괴) · `dangerText` **#D85A30** (조용한 파괴/휴지통)
- [ ] `matchChip` **rgb(199,202,70) @18%** (검색 매치 칩 배경)
- [ ] 반경: `radiusControl` **8** (버튼·입력·칩) / `radiusCard` **12** (카드·패널)

## 1. 패널 외곽 (Panel chrome)
- [ ] 패널 배경: panelBg(또는 bgContainer) · 외곽 모서리 **radius 12** · 테두리 **neutralBorder 1px**
- [ ] 콘텐츠 좌우 패딩 16 · 헤더 top 16 / bottom 12 · 하단 12
- [ ] 리사이즈 핸들(있으면): 중립 캡슐, idle/드래그 톤 토큰화

## 2. 헤더 (Header)
- [ ] 타이틀: **textPrimary**, 17px(뒤로 있을 때)/20px(루트), weight medium — **골드 금지**
- [ ] 뒤로 "◀": **textSecondary** ~16px
- [ ] 톱니 "⚙": **textTertiary** ~18–20px
- [ ] 정지 상태 깜빡이는 커서 **제거** (검색 입력 시에만)
- [ ] (검색 활성 시) 검색 박스: bg **surface** · 테두리 idle **neutralBorder 1px** / 포커스 **focusBorder 1.5px** · radius 8 · 높이 ~34 · 좌측 돋보기 glyph **textTertiary** ~14px · 입력 텍스트 15px **textPrimary** · placeholder **"Search clipboard…"** textTertiary · 캐럿 **accentPrimary**

## 3. 루트 폴더 목록
- [ ] 행: 좌우 패딩 12 / 상하 8 · 행 간격 2
- [ ] 폴더 아이콘: 14px · 선택 **accentPrimary** / 비선택 **textTertiary** · 아이콘-라벨 간격 10
- [ ] 폴더명: **textPrimary** 15px
- [ ] 카운트: **textTertiary** 12px medium, 우측 정렬 (필 배경 제거)
- [ ] 선택 바(SelectionBar): 폭 **3px** · 선택 **accentPrimary** / 비선택 **neutralBorder** · **풀하이트** · 글로우 없음
- [ ] 선택 행 배경: **surface** · radius 8
- [ ] New folder(하단 고정): "+" + "New folder" **textTertiary** · 점선 **neutralBorder** · radius 8
- [ ] 푸터(하단 고정): "N folders · M items" **textTertiary** 11px

## 4. 폴더 아이템 목록
- [ ] 선택 카드: bg **surface** · **radius 12** · 패딩 H14 V11 · 글로우 없음
- [ ] 선택 바: 폭 3px · **accentPrimary** · 풀하이트 · 글로우 없음
- [ ] 메모 줄: **textPrimary** 13px medium · 1줄
- [ ] 내용: 14px · 선택 **textPrimary**(최대 15줄) / 비선택 **textSecondary**(1줄, 말줄임)
- [ ] 타임스탬프: **textTertiary** 11px · 형식 "MMM d, h:mm a" · **모노 아님** · 위 여백 8
- [ ] Paste(goldPrimary): bg **accentPrimary** · 텍스트 **panelBg** · 11px semibold · radius 8 · 패딩 H14 V5
- [ ] Edit(neutralSecondary): bg 투명(idle)/surface(active) · 테두리 **neutralBorder 0.5px** · 텍스트 textSecondary(idle)/textPrimary(active) · radius 8
- [ ] Delete: **휴지통 아이콘** 13px · idle **dangerText**(채움 없음) / 호버·포커스 **danger 채움 + textPrimary** · radius 8 · 패딩 H9 V6 · **우측 끝**(앞에 Spacer)
- [ ] 비선택 행 사이 구분선: **divider** 0.5px · 좌우 패딩 8
- [ ] New item 점선: "+" 18px + "New item" 14px **textTertiary** · 점선 **neutralBorder** · radius 8 · 패딩 12
- [ ] 하단 힌트 푸터: "↵ paste · Ctrl+N new · 삭제" **textTertiary** 11px · 패딩 V10
- [ ] (짧은 목록) "You're all caught up" void 필러: **textSecondary** 13px + 보조 **textTertiary** 11px

## 5. 편집 / 새 아이템 폼
- [ ] **CONTENT** 라벨: **textTertiary** 11px · letter-spacing ~0.4
- [ ] 내용 입력: 14px **textPrimary** · bg **surface** · radius 8 · 테두리 **neutralBorder 0.5px** · 포커스 시 **focusBorder** · minHeight ~120(편집)/80(새)
- [ ] **MEMO · optional** 라벨: **textTertiary** 11px
- [ ] 메모 입력: placeholder **"Add a note…"** · 13px medium · bg surface · radius 8 · neutralBorder 0.5px
- [ ] 버튼 행: **우측 정렬** (Spacer 후) [Cancel(neutralSecondary)] [Save ⌘↵/Ctrl+↵(goldPrimary)] · 간격 8 · **내용 필드가 위**
- [ ] 진입 시 포커스 = **내용(CONTENT)** 필드

## 6. 검색 결과
- [ ] 요약 줄: "N results" **textPrimary 13px semibold** + " for "쿼리"" **textSecondary 13px**
- [ ] 섹션 헤더: "ITEMS (N)" / "Folders (N)" · **textTertiary** 11px semibold · 대문자 · tracking ~0.8
- [ ] 매치 하이라이트: 일치 문자열 **textPrimary semibold** + 배경 **matchChip rgb(199,202,70)@18%** (인라인 칩) — 네온/골드 텍스트 아님
- [ ] 소스 배지: 좌측 점 5px(원) + 폴더/소스명 **textSecondary** 10px · bg surface · 테두리 neutralBorder 0.5px · radius 4 · 패딩 H7 V2 · 우상단
- [ ] 결과 없음: 돋보기 28px **textTertiary** + "No matches" **textSecondary** 15px + "Nothing found for "쿼리"" **textTertiary** 13px · 상단 여백 ~60

## 7. Detail 모달
- [ ] 스크림: 검정 **@55%** · 탭하면 닫힘
- [ ] 카드: 90%×80% · bg **surface** · radius 12 · 테두리 **neutralBorder 1px**
- [ ] 헤더 바: bg **surface** · 패딩 16
- [ ] 타이틀: "Detail" **textPrimary** 15px medium (볼드 화이트 아님)
- [ ] Copy: bg **accentPrimary** · 텍스트 **panelBg** · 복사 아이콘 + "Copy" · 11px semibold · radius 8 · 패딩 H12 V6
- [ ] Close: "✕" 아이콘 **textSecondary** ~12px (흰색 채움 버튼 아님)
- [ ] 본문: 14px 모노 · 색 **#cfcfc8** · 줄간격 ~6 · 패딩 24 · **선택 가능** · bg panelBg
- [ ] 메타 푸터: 구분선(divider) + "yyyy-MM-dd HH:mm · N chars" **textTertiary** 11px · 패딩 H16 V10 · bg surface

## 8. 삭제 다이얼로그
- [ ] 스크림: 검정 **@55%**
- [ ] 카드: bg **panelBg** · radius 12 · 테두리 **neutralBorder 1px** · maxWidth 320 · 패딩 20 · 그림자 검정@45% r24 y12 (네온 글로우 없음)
- [ ] 제목: 휴지통 glyph 13px **dangerText** + "Delete item" **textPrimary** 17px semibold (소문자 item, 골드 아님)
- [ ] 본문: "This item will be permanently deleted." **textSecondary** 13px
- [ ] **미리보기 블록**: 삭제 대상 내용 · 모노 13px **textSecondary** · 최대 2줄 말줄임 · bg surface · 테두리 divider · radius 8 · 패딩 H12 V10 · 빈 값이면 "(empty)"
- [ ] 버튼: (Spacer 후) [Cancel: bg surface, neutralBorder, textPrimary] [Delete ↵: bg **danger**, **textPrimary**, semibold] · radius 8 · 패딩 H16 V8

## 9. 설정
- [ ] 섹션 라벨(SHORTCUT/GENERAL/UPDATES/INFORMATION): **textTertiary** 13px semibold · 대문자 · tracking ~0.6
- [ ] 카드: bg **surface** · 테두리 **neutralBorder 1px** · radius 12
- [ ] ON 토글: 트랙 **accentPrimary** (차분한 골드, 네온 아님)
- [ ] 세그먼트 트랙: 흰색@6% · radius 8 · 패딩 3 · 선택 칩 **matchChip(골드@18%) + textPrimary semibold** · 미선택 **textSecondary** · 칩 radius 6 · 패딩 H10 V4
- [ ] 키캡(⌘⇧V 등): bg 흰색@8% · radius 8 · 테두리 neutralBorder 1px · 텍스트 **textPrimary** 13px semibold 모노
- [ ] 행: 최소 높이 ~28 · 패딩 H14 V12 (단/2줄 행 정렬 일관)
- [ ] 정보 행: 라벨 **textSecondary** · 값 **textPrimary**
- [ ] 화면 전체 **네온 #DCDC57 0건**

---

### 검증 (각 화면 구현 후)
- [ ] 색은 전부 토큰 참조(하드코딩 hex 없음) — grep으로 #DCDC57·생 hex 0건 확인
- [ ] 화면당 골드(accentPrimary) = 주요 액션 1개에만
- [ ] 선택 = 골드 바 + surface 틴트(글로우/네온 테두리 없음)
- [ ] macOS `ui-mockups/index.html` 개선안과 나란히 비교
