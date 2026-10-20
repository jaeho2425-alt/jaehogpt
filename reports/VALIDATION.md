# NotchConvert 0.3.2 자동 검증 결과

## 변경

- 내장 Python 실행 파일의 UTF-8 모드를 빌드 시 고정하고 앱에서도 UTF-8 설정을 전달합니다.
- JSON 응답을 ASCII 이스케이프로 출력해 한글 이름과 메시지가 stdout 문자 설정에 영향을 받지 않게 했습니다.
- 자식 프로세스의 표준 입력을 명시적으로 연결합니다.
- 실행 파일 누락·실행 실패·시그널 중단·응답 해석 실패를 구분합니다. 종료 상태와 stderr는 자동 전송하지 않고 앱의 “문제 정보 복사” 버튼으로 확인할 수 있습니다.
- GUI의 ConverterModel·WorkerClient를 통한 검사와 새 운영체제 호환성 검사를 추가했습니다.

## 테스트 서버와 결과

- GitHub Actions macOS 15 ARM·Intel: https://github.com/jaeho2425-alt/jaehogpt/actions/runs/39369274862
- GitHub Actions macOS 27.0.1 ARM: https://github.com/jaeho2425-alt/jaehogpt/actions/runs/39369542579
- 다운로드: https://github.com/jaeho2425-alt/jaehogpt/releases/tag/test-6
- 앱 소스: d5b84dab72cb6dabf833a5b1e0efe231f6b2982c
- macOS 27 검사 설정: 4b2e454ad748e70ae33813e1317c6edda124cc98

공통 테스트 53개가 통과했습니다. Keynote가 서버에 없어 실제 문서 내보내기 검사 15개는 건너뛰었습니다.

세 테스트 서버에서 PKG를 설치하고 앱을 Launch Services로 실행했습니다. 자동 생성한 한글·공백·작은따옴표가 포함된 PPTX를 앱 모델에 전달해 파일 확인·PPTX 사본·ZIP 압축·원본 옆 저장·원본 보존·손상 문서 응답 처리를 확인했습니다. 최소 환경 변수와 ASCII stdio 설정에서도 같은 검사가 통과했습니다. 첫 실행 창과 접은 창의 재열기도 통과했습니다.

macOS 27.0.1 테스트 서버에서는 이전 0.3.1 PKG의 내장 엔진 검사도 통과했습니다. 이어서 0.3.2로 업그레이드하고 새 GUI 검사가 통과했습니다.

내려받은 두 설치 파일의 아카이브 SHA-256·ZIP CRC·XAR 헤더와 PKG SHA-256을 확인했습니다. PKG 체크섬은 빌드 서버 및 릴리스 자산의 값과 일치합니다.

## 확인 범위

PPTX 결과는 원본 바이트를 보존하는 같은 형식의 사본입니다. ZIP은 원본을 동일한 바이트로 복원할 수 있는지 검사했습니다. 실제 Keynote 내보내기와 문서 레이아웃, Finder의 Shift 드래그·원형 메뉴 드롭, 자동화 권한은 이 자동 검사의 범위에 포함되지 않습니다. 테스트 서버 통과가 모든 설치 환경의 정상 동작을 보장하지는 않습니다.

Apple 공증과 Developer ID 서명은 적용하지 않은 테스트 버전입니다. 업데이트 전에는 실행 중인 앱을 종료해야 새 버전이 실행됩니다.

## PKG SHA-256

- Apple Silicon: 0af3ace46ec11699afbad49d91db143a601dbebe49c19b97054f40288dc58465
- Intel: 79ea68ae39105a58d8ecfbb9912322e13d550ff83a188f68b9ff5e9fceb86bdc
