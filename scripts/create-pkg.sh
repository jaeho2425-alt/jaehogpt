#!/bin/bash
# Standard macOS Installer package: copies only the app to /Applications.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo '설치 파일 생성에는 macOS가 필요합니다.' >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD_PYTHON="${NOTCHCONVERT_PYTHON:-python3}"
bash scripts/build-macos.sh
VERSION="$(cat VERSION)"
MACHINE_ARCH="$(uname -m)"
PKG="$ROOT/dist/NotchConvert-$VERSION-$MACHINE_ARCH-test.pkg"
PKG_TMP="$(mktemp -d "${TMPDIR:-/tmp}/notchconvert-pkg.XXXXXX")"
trap 'rm -rf "$PKG_TMP"' EXIT
mkdir -p "$PKG_TMP/payload"
ditto dist/NotchConvert.app "$PKG_TMP/payload/NotchConvert.app"
pkgbuild --analyze --root "$PKG_TMP/payload" "$PKG_TMP/components.plist"
"$BUILD_PYTHON" - "$PKG_TMP/components.plist" <<'PY'
from pathlib import Path
import plistlib, sys
path = Path(sys.argv[1])
components = plistlib.loads(path.read_bytes())
for component in components:
    component['BundleIsRelocatable'] = False
    component['BundleHasStrictIdentifier'] = True
    component['BundleIsVersionChecked'] = True
    component['BundleOverwriteAction'] = 'upgrade'
path.write_bytes(plistlib.dumps(components))
PY
pkgbuild --root "$PKG_TMP/payload" --component-plist "$PKG_TMP/components.plist" \
  --install-location /Applications --ownership recommended \
  --identifier local.notchconvert.installer --version "$VERSION" "$PKG_TMP/NotchConvert.pkg"
# No root postinstall scripts and no build commands run on the test user's Mac.
pkgutil --payload-files "$PKG_TMP/NotchConvert.pkg" > "$PKG_TMP/payload-files.txt"
grep -q 'NotchConvert.app/Contents/MacOS/NotchConvert' "$PKG_TMP/payload-files.txt"
grep -q 'NotchConvert.app/Contents/Resources/worker/NotchConvertWorker' "$PKG_TMP/payload-files.txt"
if grep -q -E '(^|/)(venv|\.venv|Sources)(/|$)' "$PKG_TMP/payload-files.txt"; then
  echo '설치 파일에 개발 환경이 포함되어 있습니다.' >&2
  exit 1
fi
mv -f "$PKG_TMP/NotchConvert.pkg" "$PKG"
shasum -a 256 "$PKG" > "$PKG.sha256"
printf '설치 파일 생성 완료: %s\n' "$PKG"
