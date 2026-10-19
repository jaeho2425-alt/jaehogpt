"""Reject wrong-architecture, newer-OS, or builder-specific Mach-O dependencies."""
import argparse
from pathlib import Path
import re
import subprocess

MAGIC = {bytes.fromhex(x) for x in ('feedface', 'cefaedfe', 'feedfacf', 'cffaedfe',
                                  'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca')}

def os_version(value):
    return tuple((list(map(int, value.split('.'))) + [0, 0])[:3])

def verify(app, architecture, minimum):
    count = 0
    for path in app.rglob('*'):
        if not path.is_file():
            continue
        with path.open('rb') as stream:
            if stream.read(4) not in MAGIC:
                continue
        arches = subprocess.check_output(['lipo', '-archs', str(path)], text=True).split()
        if architecture not in arches:
            raise RuntimeError(f'{path}: {architecture} 코드가 없습니다({arches}).')
        commands = subprocess.check_output(['otool', '-arch', architecture, '-l', str(path)], text=True)
        for block in re.split(r'(?m)^Load command \d+\n', commands):
            if 'cmd LC_BUILD_VERSION' in block:
                match = re.search(r'(?m)^\s+minos ([\d.]+)', block)
            elif 'cmd LC_VERSION_MIN_MACOSX' in block:
                match = re.search(r'(?m)^\s+version ([\d.]+)', block)
            else:
                continue
            if match and os_version(match[1]) > os_version(minimum):
                raise RuntimeError(f'{path}: macOS {match[1]} 이상이 필요합니다. macOS {minimum} 호환 Python으로 빌드해 주세요.')
        libraries = subprocess.check_output(['otool', '-arch', architecture, '-L', str(path)], text=True)
        for line in libraries.splitlines():
            if not line.startswith('\t'):
                continue
            dependency = line.strip().split(' (', 1)[0]
            if dependency.startswith('/') and not dependency.startswith(('/usr/lib/', '/System/Library/')):
                # A dylib may show its own install name. Builder paths still must not remain.
                raise RuntimeError(f'{path}: 앱 밖의 라이브러리를 참조합니다: {dependency}')
        count += 1
    if count == 0:
        raise RuntimeError('앱에서 실행 파일을 찾지 못했습니다.')
    print(f'{count}개 Mach-O 파일의 아키텍처·최소 OS·외부 의존성 검사 통과')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    parser.add_argument('architecture', choices=['arm64', 'x86_64'])
    parser.add_argument('--minimum', default='13.0')
    args = parser.parse_args()
    verify(args.app, args.architecture, args.minimum)
