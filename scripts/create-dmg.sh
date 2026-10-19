#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'DMG 생성에는 macOS의 hdiutil과 Swift 빌드 도구가 필요합니다.' >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD_PYTHON="${NOTCHCONVERT_PYTHON:-python3}"
# Always package the current source; do not silently distribute an old .app.
bash scripts/build-macos.sh
VERSION="$(cat VERSION)"
MACHINE_ARCH="$(uname -m)"
DMG="$ROOT/dist/NotchConvert-$VERSION-$MACHINE_ARCH-test.dmg"
DMG_TMP="$(mktemp -d "${TMPDIR:-/tmp}/notchconvert-dmg.XXXXXX")"
trap 'rm -rf "$DMG_TMP"' EXIT
mkdir -p "$DMG_TMP/payload"
ditto dist/NotchConvert.app "$DMG_TMP/payload/NotchConvert.app"
ln -s /Applications "$DMG_TMP/payload/Applications"
cp packaging/INSTALL-ko.txt "$DMG_TMP/payload/설치 안내.txt"
hdiutil create -volname NotchConvert -srcfolder "$DMG_TMP/payload" \
  -format UDZO -ov "$DMG_TMP/NotchConvert.dmg"
hdiutil verify "$DMG_TMP/NotchConvert.dmg"
bash scripts/verify-dmg.sh "$DMG_TMP/NotchConvert.dmg"
# Publish only after the mounted payload has passed its checks.
mv -f "$DMG_TMP/NotchConvert.dmg" "$DMG"
shasum -a 256 "$DMG" > "$DMG.sha256"
printf '\n테스트용 DMG 생성 완료: %s\n' "$DMG"
printf '이 파일을 다른 Mac에 전달하면 Python이나 Xcode 설치 없이 테스트할 수 있습니다.\n'
