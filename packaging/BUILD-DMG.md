# 테스트용 DMG 만들기

현재 작업 환경은 Linux입니다. **이 폴더는 DMG 생성 도구이며, 빌드된 Mac 앱이나 DMG 파일이 아닙니다.** 실제 앱 컴파일과 DMG 생성·마운트 검사는 Mac에서 수행해야 합니다.

## 빌드하는 Mac에서 한 번

필요 사항: macOS 13 이상, Xcode Command Line Tools, Python 3.10 이상, 패키지 다운로드용 인터넷 연결. macOS 13 호환 Python을 사용하세요. 예: python.org의 Python 3.12 설치본. Homebrew Python의 라이브러리가 더 최신 macOS를 요구하면 빌드 검사가 이를 알려줍니다.

1. 프로젝트 ZIP을 Mac에서 압축 해제합니다.
2. `DMG 만들기.command`를 더블 클릭합니다. 또는 프로젝트 폴더의 터미널에서 `bash scripts/create-dmg.sh`를 실행합니다.
3. `dist/NotchConvert-0.3.0-arm64-test.dmg` 또는 `dist/NotchConvert-0.3.0-x86_64-test.dmg`를 받습니다.

빌드한 Mac과 같은 칩 종류용 DMG가 생성됩니다. Apple Silicon용과 Intel용을 모두 배포하려면 각각 해당 환경에서 빌드해야 합니다. Python과 터미널의 아키텍처가 다르면 빌드를 중단합니다. 필요하면 `NOTCHCONVERT_PYTHON=/절대/경로/python3`로 빌드용 Python을 지정하세요.

빌드 스크립트는 사용자 시스템에 패키지를 설치하지 않습니다. 임시 가상환경에 빌드 도구를 설치하고, 변환 엔진과 Python 런타임을 앱 안에 포함한 후 임시 환경을 지웁니다. 개발 도구가 없다면 `xcode-select --install`로 Command Line Tools를 먼저 설치해야 합니다. 빌드에는 관리자 권한을 요청하지 않습니다.

## 테스트 사용자에게 전달

DMG 파일 하나를 전달합니다. 테스트 사용자는 DMG를 열고 `NotchConvert.app`을 `Applications`에 드래그하면 됩니다. 설치된 앱을 실행하기 전에 DMG를 꺼내세요.

테스트 사용자에게 필요한 것은 호환 macOS와 Keynote입니다. Python·Xcode·LibreOffice를 설치할 필요가 없습니다. 앱은 시스템 확장이나 백그라운드 서비스를 설치하지 않습니다. 앱을 종료하고 휴지통으로 옮기면 제거됩니다.

기본 빌드는 로컬 테스트용 ad-hoc 서명이며 Apple 공증은 하지 않습니다. 다른 Mac에서 실행이 차단되면 실행을 한 번 시도한 뒤 시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기를 사용하세요. 보안 기능을 전체 해제하거나 quarantine 속성을 일괄 제거하는 절차는 사용하지 않습니다.

개발자 인증서가 이미 구성된 빌드 환경에서는 `NOTCHCONVERT_SIGN_IDENTITY`에 Developer ID Application 인증서 이름을 지정할 수 있습니다. 이 경우에도 공증은 자동 제출하지 않습니다.

## 생성 중 자동으로 검사하는 것

- Swift 앱 컴파일과 plist 형식.
- Python·PDF 엔진·Keynote AppleScript 리소스 포함.
- 모든 Mach-O 파일의 칩 종류, 최소 macOS, 빌드 머신에만 있는 외부 라이브러리 참조.
- 앱 코드 서명 검증.
- 한글·공백 경로로 내장 엔진을 복사하여 시스템 Python/PATH 의존 없이 실행.
- PDF/JPEG/PNG 코덱, PPTX 원본 복사, ZIP 압축 후 원본 비교.
- DMG 자체 무결성과 읽기 전용 마운트 상태의 앱·내장 엔진 검사.
- 최종 DMG의 SHA-256 체크섬 파일.

이 검사가 실제 Keynote 내보내기와 노치 UI 검증을 대신하지는 않습니다. 해당 Mac에서 `bash scripts/verify-macos.sh` 및 README의 수동 항목을 확인해야 합니다.
