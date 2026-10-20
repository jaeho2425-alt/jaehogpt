#!/bin/bash
# Build one native architecture, including a relocatable frozen conversion worker.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo '앱 빌드는 macOS 13 이상에서 실행해 주세요.' >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD_PYTHON="${NOTCHCONVERT_PYTHON:-python3}"
command -v swift >/dev/null || { echo 'Xcode Command Line Tools가 필요합니다: xcode-select --install' >&2; exit 1; }
command -v "$BUILD_PYTHON" >/dev/null || { echo '빌드용 Python 3.10 이상을 설치해 주세요.' >&2; exit 1; }
"$BUILD_PYTHON" -c 'import sys; assert sys.version_info >= (3,10), "Python 3.10 이상이 필요합니다."'
MACHINE_ARCH="$(uname -m)"
PYTHON_ARCH="$("$BUILD_PYTHON" -c 'import platform; print(platform.machine())')"
if [[ "$MACHINE_ARCH" != "$PYTHON_ARCH" ]]; then
  echo "터미널($MACHINE_ARCH)과 Python($PYTHON_ARCH)의 아키텍처가 다릅니다. 같은 아키텍처로 실행해 주세요." >&2
  exit 1
fi
SIGN_IDENTITY="${NOTCHCONVERT_SIGN_IDENTITY:--}"
# A disposable build tree avoids old venvs, stale runtime files, and user-specific paths.
BUILD_TMP="$(mktemp -d "${TMPDIR:-/tmp}/notchconvert-build.XXXXXX")"
trap 'rm -rf "$BUILD_TMP"' EXIT
"$BUILD_PYTHON" -m venv "$BUILD_TMP/venv"
PACK_PYTHON="$BUILD_TMP/venv/bin/python3"
"$PACK_PYTHON" -m pip install -r packaging/requirements.txt
VERSION="$(cat VERSION)"
# Compile native source against the declared macOS minimum, not the build host's OS.
export MACOSX_DEPLOYMENT_TARGET=13.0
swift build -c release
BIN="$(swift build -c release --show-bin-path)"
# No Python interpreter, venv, or developer tools are needed on the test user's Mac.
"$PACK_PYTHON" -m PyInstaller --noconfirm --clean --onedir \
  --name NotchConvertWorker --target-arch "$MACHINE_ARCH" \
  --python-option "X utf8" \
  --collect-all pymupdf \
  --add-data "$ROOT/backend/export-keynote.applescript:." \
  --codesign-identity "$SIGN_IDENTITY" \
  --osx-entitlements-file "$ROOT/packaging/entitlements.plist" \
  --specpath "$BUILD_TMP/spec" --workpath "$BUILD_TMP/work" --distpath "$BUILD_TMP/frozen" \
  "$ROOT/backend/converter.py"
APP="$ROOT/dist/NotchConvert.app"
APP_STAGE="$BUILD_TMP/NotchConvert.app"
mkdir -p "$APP_STAGE/Contents/MacOS" "$APP_STAGE/Contents/Resources"
cp "$BIN/NotchConvert" "$APP_STAGE/Contents/MacOS/NotchConvert"
ditto "$BUILD_TMP/frozen/NotchConvertWorker" "$APP_STAGE/Contents/Resources/worker"
"$PACK_PYTHON" scripts/write-info-plist.py "$VERSION" "$APP_STAGE/Contents/Info.plist"
cp packaging/INSTALL-ko.txt "$APP_STAGE/Contents/Resources/설치 안내.txt"
plutil -lint "$APP_STAGE/Contents/Info.plist"
"$PACK_PYTHON" scripts/check-macos-binaries.py "$APP_STAGE" "$MACHINE_ARCH" --minimum 13.0
# The worker's nested libraries are signed by PyInstaller. Sign the enclosing app last.
if [[ "$SIGN_IDENTITY" == - ]]; then
  codesign --force --sign - --entitlements packaging/entitlements.plist "$APP_STAGE"
else
  codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp \
    --entitlements packaging/entitlements.plist "$APP_STAGE"
fi
codesign --verify --deep --strict --verbose=2 "$APP_STAGE"
# Exercise the frozen engine from a path with spaces, without importing from a venv.
"$PACK_PYTHON" scripts/check-worker.py "$APP_STAGE/Contents/Resources/worker/NotchConvertWorker"
mkdir -p dist
# Replace only the generated app after all build checks pass; preserve previous build on failure.
rm -rf "$APP"
ditto "$APP_STAGE" "$APP"
printf '앱 생성 완료: %s\n' "$APP"
