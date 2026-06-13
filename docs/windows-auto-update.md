# Windows(Tauri) 앱 자동 업데이트 설정 가이드

Tauri 앱(`apps/windows/`)은 `tauri-plugin-updater`로 자동 업데이트를 지원한다.
macOS 네이티브 앱의 Sparkle와는 별개 체계이며, 서명 키도 별도다.

> **현재 상태**: 코드/설정은 모두 들어가 있으나 `tauri.conf.json`의 `pubkey`가
> 플레이스홀더(`REPLACE_WITH_TAURI_SIGNER_PUBLIC_KEY`)다. 아래 1번을 수행해
> 실제 공개키로 교체하기 전까지 업데이트 체크는 "Update check failed."로 끝난다
> (앱의 다른 기능에는 영향 없음).

## 1. 서명 키 생성 (1회, 직접 수행 필요)

```bash
cd apps/windows/src-tauri
cargo tauri signer generate -w ~/.tauri/pastesheets-updater.key
```

- 비밀키(`~/.tauri/pastesheets-updater.key`)는 **절대 저장소에 커밋하지 말 것**.
  비밀번호를 설정했다면 함께 보관.
- 출력된 **공개키**를 `apps/windows/src-tauri/tauri.conf.json` →
  `plugins.updater.pubkey`에 붙여넣는다 (공개키는 커밋해도 안전).

## 2. 릴리스 빌드 (서명 포함)

```bash
export TAURI_SIGNING_PRIVATE_KEY=$(cat ~/.tauri/pastesheets-updater.key)
export TAURI_SIGNING_PRIVATE_KEY_PASSWORD="<설정했다면>"
cd apps/windows && cargo tauri build
```

`bundle.createUpdaterArtifacts: true` 덕에 빌드 산출물 옆에 `.sig` 서명 파일이
함께 생성된다 (Windows는 `*-setup.exe` + `.sig`).

## 3. GitHub Release 업로드

업데이트 엔드포인트는 다음으로 고정되어 있다:

```
https://github.com/newfull5/PasteSheets/releases/latest/download/latest.json
```

각 릴리스에 다음을 자산으로 올린다:

1. 설치 파일 (`PasteSheet_<버전>_x64-setup.exe` 등)
2. 해당 `.sig` 파일 내용이 들어간 `latest.json`:

```json
{
  "version": "0.3.0",
  "notes": "변경 사항 요약",
  "pub_date": "2026-06-11T00:00:00Z",
  "platforms": {
    "windows-x86_64": {
      "signature": "<.sig 파일 내용 전체>",
      "url": "https://github.com/newfull5/PasteSheets/releases/download/v0.3.0/PasteSheet_0.3.0_x64-setup.exe"
    }
  }
}
```

`tauri-action` GitHub Action을 쓰면 2–3번이 자동화된다
(`TAURI_SIGNING_PRIVATE_KEY`를 repo secret으로 등록).

## 앱 동작

- **Settings > Updates > Automatic Updates** (기본 on, `auto_update_enabled` 키):
  앱 시작 시 백그라운드로 체크하고, 새 버전이 있으면 설치 확인 모달을 띄운다.
- **Check Now**: 수동 체크. 최신이면 "You're up to date.", 실패 시
  "Update check failed."를 버튼 옆에 표시.
- 설치 확정 시 다운로드 → 설치 → 자동 재시작(`relaunch`).
