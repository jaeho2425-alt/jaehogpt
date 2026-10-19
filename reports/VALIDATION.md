# NotchConvert 0.3.0 검증 결과

실제 macOS에서 Apple Silicon·Intel 설치 파일을 생성했습니다.

- 빌드 및 설치 검사: https://github.com/jaeho2425-alt/jaehogpt/actions/runs/39272718683
- 다운로드: https://github.com/jaeho2425-alt/jaehogpt/releases/tag/test-3
- 앱 소스 커밋: 428a0da908d55af42a58adf025036797fd789e6f

## 통과한 검사

양쪽 Mac 서버에서 Swift 앱 컴파일, 공통 테스트 52개, 60개 Mach-O 파일의 아키텍처·최소 macOS·외부 라이브러리 검사, 앱 서명 검증을 통과했습니다.

내장 Python 실행 파일을 한글·공백 경로로 재배치한 뒤 PDF/JPEG/PNG 코덱, PPTX 바이트 복사, ZIP 원본 복원, 원본 옆 저장과 중복 이름 보존을 검사했습니다.

생성된 PKG를 macOS Installer로 실제 /Applications에 설치하고 설치된 앱의 서명·내장 엔진을 다시 확인했습니다. 앱 실행 후 프로세스가 정상 유지되는 것도 확인했습니다. 설치 후 테스트 사용자에게 Python이나 개발 도구가 필요하지 않습니다.

Mac의 /var와 /private/var가 같은 폴더를 가리키는 문제 때문에 검사 경로 비교가 처음 실패했습니다. 실제 파일 위치를 비교하도록 검사 도구를 수정한 후 재검증했습니다.

다운로드한 두 PKG의 ZIP CRC, XAR 패키지 헤더, SHA-256을 빌드 서버가 생성한 값과 대조했습니다.

## 남은 실제 사용 검사

Keynote를 설치한 사용자 Mac에서의 실제 KEY/PPT/PPTX 변환 15개 검사는 서버에 Keynote가 없어 건너뛰었습니다. Keynote 내보내기를 대체하는 처리 흐름 검사와 실제 Keynote 내보내기 검사를 구분해야 합니다.

Shift 감지·원형 메뉴 드롭·노치 접근·Keynote 자동화 권한·실제 문서의 글꼴과 레이아웃은 사용자 Mac에서 확인해야 합니다. 앱 실행 성공이 모든 UI와 실제 문서 변환 성공을 의미하지는 않습니다.

초기 테스트용으로 Apple 공증과 Developer ID 인증서 서명은 적용하지 않았습니다. 실행이 차단되면 시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기(Open Anyway)를 사용할 수 있습니다.

## 설치 파일 SHA-256

- Apple Silicon: a89cfb9acb64b570388ffe7e6ef27ca13f9b756d2244c0c654ce54b8f1f6dbe4
- Intel: b1e9bc411915a1be93c8fe2cc8c928726a7aadc1dd8b9c86c75e9633e566fc12
