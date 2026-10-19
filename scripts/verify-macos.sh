#!/bin/bash
# Native compilation plus actual Keynote exports, never a mocked native pass.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo '이 검증은 Keynote가 설치된 macOS 13 이상에서 실행해 주세요.' >&2
  exit 1
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash scripts/build-macos.sh
python3 -m venv .venv-tests
.venv-tests/bin/python -m pip install -r tests/requirements.txt
mkdir -p reports
.venv-tests/bin/python - <<'PY'
import sys
sys.path.insert(0, 'backend')
from converter import keynote_available
if not keynote_available():
    raise SystemExit('Keynote를 설치하고 한 번 실행한 뒤 다시 검증해 주세요.')
PY
# Compile against this Mac's Keynote scripting dictionary before running exports.
osacompile -o reports/export-keynote.scpt backend/export-keynote.applescript
osacompile -o reports/make-fixture.scpt tests/make-keynote-fixture.applescript
export NOTCHCONVERT_RUN_KEYNOTE_TESTS=1
export NOTCHCONVERT_NATIVE_WORKER="$ROOT/dist/NotchConvert.app/Contents/Resources/worker/NotchConvertWorker"
export NOTCHCONVERT_MATRIX_REPORT="$ROOT/reports/matrix-macos.json"
# Remove only the previous generated report so an old success cannot mask skipped tests.
rm -f "$NOTCHCONVERT_MATRIX_REPORT"
.venv-tests/bin/python -m unittest discover -s tests -v 2>&1 | tee reports/macos.log
.venv-tests/bin/python - <<'PY'
import json, os
from pathlib import Path
rows = json.loads(Path(os.environ['NOTCHCONVERT_MATRIX_REPORT']).read_text())
assert len(rows) == 15 and all(r['status'] == 'passed' for r in rows), '일부 네이티브 변환 조합이 실패했거나 실행되지 않았습니다.'
print('실제 Keynote 변환 15개 조합 통과. 노치 드래그와 앱의 자동화 권한은 README의 수동 항목을 확인하세요.')
PY
