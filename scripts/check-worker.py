"""Smoke-test a relocated frozen worker without Python/PATH dependencies on the target."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile


def call(worker, *args):
    env = os.environ.copy()
    for name in ('PYTHONHOME', 'PYTHONPATH', 'VIRTUAL_ENV'):
        env.pop(name, None)
    env['PATH'] = '/usr/bin:/bin:/usr/sbin:/sbin'
    result = subprocess.run([str(worker), *map(str, args)], capture_output=True, text=True, env=env, timeout=60)
    try:
        reply = json.loads(result.stdout)
    except ValueError as exc:
        raise RuntimeError('내장 엔진의 응답을 읽지 못했습니다: ' + result.stderr[-1000:]) from exc
    if result.returncode != 0 or not reply.get('ok'):
        raise RuntimeError('내장 엔진 확인 실패: ' + str(reply.get('error', result.stderr[-1000:])))
    return reply


def smoke_test(worker):
    with tempfile.TemporaryDirectory(prefix='notchconvert packaged ') as temp:
        root = Path(temp)
        relocated = root / '변환 도구'
        shutil.copytree(worker.parent, relocated, symlinks=True)
        executable = relocated / worker.name
        status = call(executable, 'self-check')
        if status.get('mode') != 'bundled' or status.get('image_codecs') != ['jpeg', 'png']:
            raise RuntimeError('독립 실행형 변환 도구가 아닙니다.')
        # Minimal OOXML container exercises literal Unicode paths, ZIP and same-format copy.
        source = root / "테스트 ' 문서.pptx"
        with zipfile.ZipFile(source, 'w') as archive:
            archive.writestr('[Content_Types].xml', '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>')
            archive.writestr('ppt/presentation.xml', '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"/>')
        original = source.read_bytes()
        for fmt in ('pptx', 'zip'):
            reply = call(executable, 'convert', '--format', fmt, '--output', root / '결과 폴더', source)
            paths = [Path(p) for p in reply['outputs']]
            if len(paths) != 1:
                raise RuntimeError('결과 파일 수가 올바르지 않습니다.')
            if fmt == 'pptx':
                if paths[0].read_bytes() != original:
                    raise RuntimeError('PowerPoint 복사 결과가 원본과 다릅니다.')
            else:
                with zipfile.ZipFile(paths[0]) as archive:
                    if archive.testzip() is not None or archive.read(archive.namelist()[0]) != original:
                        raise RuntimeError('ZIP 원본 보존 확인에 실패했습니다.')
        nearby = call(executable, 'convert', '--format', 'pptx', '--beside-original', source)
        near_path = Path(nearby['outputs'][0])
        if near_path.parent != source.parent or near_path == source or near_path.read_bytes() != original:
            raise RuntimeError('원본 옆 저장·중복 이름 보존 확인에 실패했습니다.')
        if source.read_bytes() != original:
            raise RuntimeError('테스트 중 원본이 변경되었습니다.')
        print(json.dumps({'ok': True, 'worker': status, 'relocation': True,
                          'checks': ['pdf/jpeg/png codecs', 'pptx byte copy', 'zip roundtrip', 'unicode paths', 'beside-original without overwrite']},
                         ensure_ascii=False))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('worker', type=Path)
    args = parser.parse_args()
    smoke_test(args.worker.resolve())
