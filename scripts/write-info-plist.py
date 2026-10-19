"""Write bundle metadata using plistlib so dynamic values are escaped correctly."""
import argparse
from pathlib import Path
import plistlib
import re


def make_info(version):
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('VERSION은 0.2.0 같은 세 자리 숫자여야 합니다.')
    return {
        'CFBundleExecutable': 'NotchConvert',
        'CFBundleIdentifier': 'local.notchconvert.app',
        'CFBundleName': 'NotchConvert',
        'CFBundleDisplayName': 'NotchConvert',
        'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': version,
        'CFBundleVersion': version,
        'LSMinimumSystemVersion': '13.0',
        'LSUIElement': True,
        'LSApplicationCategoryType': 'public.app-category.productivity',
        'NSHighResolutionCapable': True,
        'NSAppleEventsUsageDescription': '프레젠테이션을 PDF와 PowerPoint로 내보내기 위해 Keynote를 제어합니다.',
    }

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('version')
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_bytes(plistlib.dumps(make_info(args.version), sort_keys=False))
