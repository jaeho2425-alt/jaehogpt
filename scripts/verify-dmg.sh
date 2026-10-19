#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'DMG 검증은 macOS에서 실행해 주세요.' >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG="${1:?검증할 DMG 경로를 지정해 주세요.}"
BUILD_PYTHON="${NOTCHCONVERT_PYTHON:-python3}"
MOUNT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/notchconvert-mount.XXXXXX")"
MOUNTED=0
cleanup() {
  if [[ "$MOUNTED" == 1 ]]; then
    if ! hdiutil detach "$MOUNT_TMP/volume"; then
      printf '디스크를 꺼내지 못했습니다. Finder에서 꺼낸 뒤 %s 폴더를 삭제해 주세요.\n' "$MOUNT_TMP" >&2
      return
    fi
  fi
  rm -rf "$MOUNT_TMP"
}
trap cleanup EXIT
mkdir -p "$MOUNT_TMP/volume"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_TMP/volume" "$DMG"
MOUNTED=1
APP="$MOUNT_TMP/volume/NotchConvert.app"
test -x "$APP/Contents/MacOS/NotchConvert"
test -x "$APP/Contents/Resources/worker/NotchConvertWorker"
test -L "$MOUNT_TMP/volume/Applications"
test "$(readlink "$MOUNT_TMP/volume/Applications")" == /Applications
plutil -lint "$APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP"
"$BUILD_PYTHON" "$ROOT/scripts/check-worker.py" "$APP/Contents/Resources/worker/NotchConvertWorker"
echo 'DMG 마운트·앱 서명·내장 엔진 검사 통과. Keynote 변환과 앱 화면은 별도 Mac 테스트가 필요합니다.'
