"""Keynote/PowerPoint-only conversion worker. stdout is a single JSON response."""
from __future__ import annotations
import argparse
import errno
from contextlib import redirect_stdout, ExitStack
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import zipfile

with redirect_stdout(sys.stderr):
    import pymupdf as fitz

FORMATS = ['pdf', 'jpeg', 'png', 'pptx', 'zip']
MAX_PAGES = 500
MAX_PIXELS = 40_000_000
EXPORT_TIMEOUT = 210
OLE_HEADER = bytes.fromhex('d0cf11e0a1b11ae1')

class ConversionError(Exception):
    pass


def keynote_available():
    if sys.platform != 'darwin':
        return False
    if any(p.is_dir() for p in [Path('/Applications/Keynote.app'), Path.home() / 'Applications/Keynote.app']):
        return True
    # Spotlight lookup also supports Keynote installed outside the standard folders.
    try:
        result = subprocess.run(['/usr/bin/mdfind', 'kMDItemCFBundleIdentifier == "com.apple.iWork.Keynote"'],
                                capture_output=True, text=True, timeout=5, env=external_environment())
        return result.returncode == 0 and any(Path(p).is_dir() for p in result.stdout.splitlines())
    except (OSError, subprocess.TimeoutExpired):
        return False


def is_keynote_package(names):
    return 'Index/Document.iwa' in names or any(name in names for name in ('index.apxl', 'index.apxl.gz'))


def validate_source(path):
    extension = path.suffix.lower()
    if extension not in {'.key', '.ppt', '.pptx'}:
        raise ConversionError(f'{path.name}: Keynote(.key) 또는 PowerPoint(.ppt·.pptx)만 추가할 수 있습니다.')
    if path.is_dir() and extension == '.key':
        names = []
        for entry in path.rglob('*'):
            if entry.is_symlink():
                raise ConversionError(f'{path.name}: 외부 파일 링크가 포함된 Keynote 패키지는 지원하지 않습니다.')
            if entry.is_file():
                names.append(entry.relative_to(path).as_posix())
        if is_keynote_package(names):
            return 'key'
    elif path.is_file():
        if extension == '.ppt':
            with path.open('rb') as source:
                if source.read(8) == OLE_HEADER and path.stat().st_size >= 512:
                    return 'ppt'
        else:
            try:
                with zipfile.ZipFile(path) as archive:
                    names = set(archive.namelist())
                    if extension == '.pptx' and {'[Content_Types].xml', 'ppt/presentation.xml'} <= names:
                        return 'pptx'
                    if extension == '.key' and is_keynote_package(names):
                        return 'key'
            except (OSError, zipfile.BadZipFile):
                pass
    raise ConversionError(f'{path.name}: 파일이 없거나 프레젠테이션 구조가 손상되었습니다.')


def inspect(paths):
    available = set(FORMATS)
    files = []
    native = keynote_available()
    for source in paths:
        kind = validate_source(source)
        formats = set(FORMATS) if native else ({'pptx', 'zip'} if kind == 'pptx' else {'zip'})
        available &= formats
        note = '' if native else 'PDF·이미지 및 문서 변환에는 Mac의 Keynote가 필요합니다.'
        files.append({'name': source.name, 'kind': kind, 'note': note})
    return {'formats': [fmt for fmt in FORMATS if fmt in available] if paths else [], 'files': files}


def safe_stem(stem):
    return stem.encode('utf-8')[:180].decode('utf-8', errors='ignore') or 'presentation'


def external_environment():
    env = os.environ.copy()
    if getattr(sys, 'frozen', False):
        # PyInstaller's search paths belong to this process, not macOS system tools.
        for variable in ('DYLD_LIBRARY_PATH', 'DYLD_FALLBACK_LIBRARY_PATH', 'LD_LIBRARY_PATH'):
            original = env.pop(variable + '_ORIG', None)
            env.pop(variable, None)
            if original is not None:
                env[variable] = original
    return env


def check_runtime():
    script = Path(__file__).with_name('export-keynote.applescript')
    if not script.is_file():
        raise ConversionError('앱에 Keynote 내보내기 도구가 포함되어 있지 않습니다.')
    # Check native PDF/image codecs inside the packaged interpreter as well as imports.
    with tempfile.TemporaryDirectory(prefix='notchconvert-runtime-') as temp:
        root = Path(temp)
        pdf = root / 'probe.pdf'
        with fitz.open() as doc:
            doc.new_page(width=40, height=30).insert_text((2, 12), 'Test', fontsize=8)
            doc.save(pdf)
        for fmt in ('jpeg', 'png'):
            render_images(pdf, fmt, root, 'probe')
            pixmap = fitz.Pixmap(str(root / f'probe-001.{fmt}'))
            if (pixmap.width, pixmap.height) != (80, 60):
                raise ConversionError('내장 이미지 변환 도구의 확인에 실패했습니다.')
    return {'mode': 'bundled' if getattr(sys, 'frozen', False) else 'python',
            'platform': sys.platform, 'architecture': platform.machine(),
            'python': platform.python_version(), 'pdf_engine': fitz.VersionBind,
            'keynote_script': True, 'image_codecs': ['jpeg', 'png']}


def native_export(source, fmt, target, work):
    """Open a private copy so Keynote never edits/closes a user's original document."""
    if not keynote_available():
        raise ConversionError('Mac에 Keynote를 설치한 뒤 다시 시도해 주세요.')
    private = work / ('source' + source.suffix.lower())
    if source.is_dir():
        shutil.copytree(source, private)
    else:
        shutil.copy2(source, private)
    script = Path(__file__).with_name('export-keynote.applescript')
    try:
        result = subprocess.run(['/usr/bin/osascript', str(script), str(private), str(target), fmt],
                                capture_output=True, text=True, timeout=EXPORT_TIMEOUT, env=external_environment())
    except subprocess.TimeoutExpired as exc:
        raise ConversionError('Keynote 응답 시간이 초과되었습니다. Keynote의 대화상자를 확인한 뒤 다시 시도해 주세요.') from exc
    if result.returncode:
        detail = result.stderr.strip()
        if '-1743' in detail:
            raise ConversionError('Keynote 제어 권한이 필요합니다. 시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 허용해 주세요.')
        if '-1712' in detail:
            raise ConversionError('Keynote 응답 시간이 초과되었습니다. 암호 입력이나 경고 대화상자를 확인해 주세요.')
        raise ConversionError(f'{source.name}: Keynote에서 내보내지 못했습니다. {detail[:400]}')
    if not target.is_file() or target.stat().st_size == 0:
        raise ConversionError(f'{source.name}: Keynote가 결과 파일을 생성하지 못했습니다.')
    if fmt == 'pdf':
        validate_pdf(target)
    else:
        validate_source(target)


def validate_pdf(path):
    try:
        with fitz.open(path) as document:
            if not document.is_pdf or document.needs_pass or not 0 < len(document) <= MAX_PAGES:
                raise ConversionError(f'암호 없는 1~{MAX_PAGES}슬라이드 문서만 지원합니다.')
    except ConversionError:
        raise
    except Exception as exc:
        raise ConversionError('Keynote가 만든 PDF를 읽을 수 없습니다.') from exc


def render_images(pdf, fmt, stage, stem):
    validate_pdf(pdf)
    with fitz.open(pdf) as document:
        for index, page in enumerate(document, 1):
            rect = page.rect
            if rect.width <= 0 or rect.height <= 0:
                raise ConversionError('슬라이드 크기가 올바르지 않습니다.')
            scale = min(2, (MAX_PIXELS / (rect.width * rect.height)) ** 0.5)
            pixmap = page.get_pixmap(matrix=fitz.Matrix(scale, scale), colorspace=fitz.csRGB, alpha=False)
            target = stage / f'{stem}-{index:03d}.{fmt}'
            if fmt == 'jpeg':
                pixmap.save(str(target), jpg_quality=92)
            else:
                pixmap.save(str(target))


def zip_sources(paths, target):
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, allowZip64=True) as archive:
        for index, source in enumerate(paths, 1):
            base = f'{index:03d}/{source.name}'
            if source.is_dir():
                archive.write(source, base + '/')
                for entry in sorted(source.rglob('*')):
                    if entry.is_symlink():
                        raise ConversionError('Keynote 패키지에 외부 파일 링크가 포함되어 있습니다.')
                    archive.write(entry, base + '/' + entry.relative_to(source).as_posix())
            else:
                archive.write(source, base)


def convert(paths, fmt, destination):
    if not paths:
        raise ConversionError('변환할 프레젠테이션을 추가해 주세요.')
    inspection = inspect(paths)
    if fmt not in inspection['formats']:
        raise ConversionError('선택한 출력 형식을 사용할 수 없습니다. Mac의 Keynote 설치 상태를 확인해 주세요.')
    # A result folder inside a .key package would alter the original and recurse during ZIP.
    for source in paths:
        if source.is_dir() and destination.resolve().is_relative_to(source.resolve()):
            raise ConversionError('저장 위치는 Keynote 원본 패키지 밖의 폴더로 선택해 주세요.')
    destination.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.notchconvert-', dir=destination))
    try:
        if fmt == 'zip':
            zip_sources(paths, stage / 'Presentations.zip')
        else:
            for index, (source, info) in enumerate(zip(paths, inspection['files']), 1):
                stem = f'{index:03d}-{safe_stem(source.stem)}'
                with tempfile.TemporaryDirectory(prefix='notchconvert-') as temp:
                    work = Path(temp)
                    if fmt == 'pptx' and info['kind'] == 'pptx':
                        # Same-format output preserves all editable objects and embedded media.
                        shutil.copyfile(source, stage / f'{stem}.pptx')
                    elif fmt in {'pdf', 'pptx'}:
                        native_export(source, fmt, stage / f'{stem}.{fmt}', work)
                    else:
                        pdf = work / 'render.pdf'
                        native_export(source, 'pdf', pdf, work)
                        render_images(pdf, fmt, stage, stem)
        result = Path(tempfile.mkdtemp(prefix='NotchConvert-', dir=destination))
        try:
            # Atomic directory rename publishes the complete batch at once (same filesystem).
            stage.replace(result)
        except Exception:
            result.rmdir()
            raise
        return {'folder': str(result), 'outputs': [str(p) for p in sorted(result.iterdir())]}
    finally:
        shutil.rmtree(stage, ignore_errors=True)


def remove_owned(path, identity):
    try:
        info = path.lstat()
        if (info.st_dev, info.st_ino) == identity:
            path.unlink()
    except FileNotFoundError:
        pass


def publish_unique(staged, desired):
    """Reserve a new name atomically; never replace an existing sibling or original."""
    for number in range(1, 10001):
        name = desired.name if number == 1 else f'{desired.stem} ({number}){desired.suffix}'
        target = desired.with_name(name)
        try:
            os.link(staged, target)
            info = target.lstat()
            return target, (info.st_dev, info.st_ino)
        except FileExistsError:
            continue
        except OSError as exc:
            if exc.errno not in {errno.EPERM, errno.EOPNOTSUPP, errno.ENOSYS, errno.EXDEV}:
                raise
        # FAT/exFAT volumes may not support hard links. Exclusive creation still
        # preserves existing files; remove only this new inode if copying fails.
        try:
            destination = target.open('xb')
        except FileExistsError:
            continue
        info = os.fstat(destination.fileno())
        identity = (info.st_dev, info.st_ino)
        try:
            with destination, staged.open('rb') as source:
                shutil.copyfileobj(source, destination)
            return target, identity
        except Exception:
            remove_owned(target, identity)
            raise
    raise ConversionError('같은 이름의 결과 파일이 너무 많습니다. 일부 결과를 다른 폴더로 옮겨 주세요.')


def convert_beside_original(paths, fmt):
    if not paths:
        raise ConversionError('변환할 프레젠테이션을 추가해 주세요.')
    inspection = inspect(paths)
    if fmt not in inspection['formats']:
        raise ConversionError('선택한 출력 형식을 사용할 수 없습니다. Keynote 설치 상태를 확인해 주세요.')
    groups = {}
    for source in paths:
        groups.setdefault(source.parent, []).append(source)
    created = []
    with ExitStack() as cleanup:
        plans = []
        # Finish all conversions before creating visible sibling files, including
        # batches whose sources are in different folders or on different volumes.
        for parent, sources in groups.items():
            stage = Path(cleanup.enter_context(tempfile.TemporaryDirectory(prefix='.notchconvert-near-', dir=parent)))
            result = convert(sources, fmt, stage)
            for value in result['outputs']:
                staged = Path(value)
                if fmt == 'zip':
                    name = (safe_stem(sources[0].stem) if len(sources) == 1 else 'Presentations') + '.zip'
                else:
                    name = staged.name.split('-', 1)[1]  # Remove the internal input index.
                plans.append((staged, parent / name))
        try:
            for staged, desired in plans:
                created.append(publish_unique(staged, desired))
        except Exception:
            for path, identity in reversed(created):
                remove_owned(path, identity)
            raise
    return {'folder': str(paths[0].parent), 'outputs': [str(path) for path, _ in created]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['inspect', 'convert', 'self-check'])
    parser.add_argument('--format', choices=FORMATS)
    location = parser.add_mutually_exclusive_group()
    location.add_argument('--output', type=Path)
    location.add_argument('--beside-original', action='store_true')
    parser.add_argument('paths', nargs='*', type=Path)
    args = parser.parse_args()
    try:
        paths = [p.expanduser().resolve() for p in args.paths]
        if args.action != 'self-check' and not paths:
            raise ConversionError('변환할 프레젠테이션을 추가해 주세요.')
        if args.action == 'convert' and (not args.format or not (args.output or args.beside_original)):
            raise ConversionError('출력 형식과 저장 폴더가 필요합니다.')
        with redirect_stdout(sys.stderr):
            if args.action == 'self-check':
                result = check_runtime()
            elif args.action == 'inspect':
                result = inspect(paths)
            elif args.beside_original:
                result = convert_beside_original(paths, args.format)
            else:
                result = convert(paths, args.format, args.output.resolve())
        # ASCII JSON is decoded as Unicode by the app and works without a GUI locale.
        print(json.dumps({'ok': True, **result}, ensure_ascii=True))
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=True))
        sys.exit(1)

if __name__ == '__main__':
    main()
