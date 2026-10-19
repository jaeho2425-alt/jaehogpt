"""Check visible first launch and Finder-style reopening of an installed app."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time


def wait_for(report, phase):
    deadline = time.monotonic() + 35
    while time.monotonic() < deadline:
        if report.exists():
            result = json.loads(report.read_text())
            if result['phase'] == 'failed':
                raise RuntimeError(result.get('error', 'Window check failed'))
            if result['phase'] == phase:
                return
        time.sleep(0.1)
    raise RuntimeError(f'App did not report {phase}')


def main():
    if sys.platform != 'darwin':
        raise SystemExit('This check requires a macOS graphical session')
    app = Path(sys.argv[1]).resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix='notchconvert-window-') as temp:
        report = Path(temp) / 'window-check.json'
        try:
            subprocess.run(['/usr/bin/open', '-n', str(app), '--args',
                            '--check-launch-window', str(report)], check=True)
            wait_for(report, 'awaiting-reopen')
            print('First launch: conversion window visible; collapsed for reopen check', flush=True)
            subprocess.run(['/usr/bin/open', str(app)], check=True)
            wait_for(report, 'passed')
            print('Reopen via Launch Services: conversion window visible', flush=True)
        finally:
            subprocess.run(['/usr/bin/pkill', '-x', 'NotchConvert'], check=False)


if __name__ == '__main__':
    main()
