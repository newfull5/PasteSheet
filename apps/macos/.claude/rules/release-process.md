# macOS Release Process

Follow this exact sequence every time. Skipping any step causes silent failures.

## 1. Version bump (on `develop`)

Edit `apps/macos/PasteSheets/Resources/Info.plist`:
- `CFBundleVersion` → increment by 1 (build number)
- `CFBundleShortVersionString` → new semver (e.g. `0.4.7`)

Commit and push to `develop`.

## 2. Build archive

```bash
cd apps/macos
xcodebuild -project PasteSheets.xcodeproj \
  -scheme PasteSheets \
  -configuration Release \
  -archivePath /tmp/PasteSheet_X.Y.Z.xcarchive \
  archive
```

## 3. Re-sign Sparkle XPC services

**MUST NOT SKIP.** Xcode leaves `Installer.xpc`, `Downloader.xpc`, and `Updater.app`
as ad-hoc signed. macOS 15 blocks XPC launch when authority doesn't match the parent app
→ "An error occurred while launching the installer".

Sign inside-out:

```bash
APP=/tmp/PasteSheet_X.Y.Z.xcarchive/Products/Applications/PasteSheet.app
CERT="PasteSheet Dev"
FW="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"

codesign --force --sign "$CERT" --timestamp=none "$FW/XPCServices/Downloader.xpc"
codesign --force --sign "$CERT" --timestamp=none "$FW/XPCServices/Installer.xpc"
codesign --force --sign "$CERT" --timestamp=none "$FW/Updater.app"
codesign --force --sign "$CERT" --timestamp=none "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "$CERT" --timestamp=none "$APP"
```

Verify:
```bash
codesign -dv "$FW/XPCServices/Installer.xpc" 2>&1 | grep -E "Signature|Authority"
# Must NOT say "Signature=adhoc"
```

## 4. Create DMG with Applications symlink

**MUST include Applications symlink** so users can drag-and-drop to install.

```bash
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname PasteSheet \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  /tmp/PasteSheet_X.Y.Z_universal.dmg
rm -rf "$STAGING"
```

## 5. Sign DMG with Sparkle EdDSA key

```bash
SIGN_UPDATE=~/Library/Developer/Xcode/DerivedData/PasteSheets-hjifljvbqyfmxxgmdydmaerelkjn/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
$SIGN_UPDATE /tmp/PasteSheet_X.Y.Z_universal.dmg
# → outputs edSignature and length — copy both
```

## 6. Create GitHub release and upload DMG

```bash
gh release create vX.Y.Z /tmp/PasteSheet_X.Y.Z_universal.dmg \
  --title "vX.Y.Z" \
  --notes "..."
```

Windows CI (`windows-build.yml`) triggers automatically on `release: published`
and attaches the `.exe`. Wait for it to finish before sharing the release link.

## 7. Update appcast.xml

Add a new `<item>` at the TOP of the channel (above all existing items).
Use the exact `edSignature` and `length` from step 5.

```xml
<item>
    <title>Version X.Y.Z</title>
    <description><![CDATA[<ul><li>...</li></ul>]]></description>
    <sparkle:version>BUILD_NUMBER</sparkle:version>
    <sparkle:shortVersionString>X.Y.Z</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <pubDate>...</pubDate>
    <enclosure
        url="https://github.com/newfull5/PasteSheet/releases/download/vX.Y.Z/PasteSheet_X.Y.Z_universal.dmg"
        length="EXACT_BYTE_COUNT"
        type="application/octet-stream"
        sparkle:edSignature="SIGNATURE_FROM_SIGN_UPDATE"
    />
</item>
```

## 8. PR develop → main and merge

```bash
git add appcast.xml
git commit -m "chore(release): macOS X.Y.Z (build N)"
git push origin develop
gh pr create --base main --head develop --assignee @me --title "Release vX.Y.Z" ...
gh pr merge PR_NUMBER --merge
```

`appcast.xml` must land on `main` — Sparkle fetches from
`raw.githubusercontent.com/.../main/appcast.xml`.

## Common mistakes

| Mistake | Symptom |
|---------|---------|
| Skip step 3 (XPC re-sign) | "An error occurred while launching the installer" |
| Skip Applications symlink in DMG | DMG opens with only the app, no drag target |
| Wrong `length` in appcast.xml | Sparkle rejects the download |
| appcast.xml not on `main` | Sparkle shows no update |
