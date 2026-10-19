# NotchConvert — Keynote / PowerPoint 전용

프레젠테이션을 드래그하다 Shift를 누르면 커서 주변에 원형 변환 메뉴가 열리는 macOS 메뉴 막대 앱의 개발 버전입니다. 화면 상단 노치 근처로 드래그해도 같은 메뉴를 열 수 있습니다. 현재 입력은 **Keynote(.key), PowerPoint(.ppt·.pptx)**뿐입니다. 일반 이미지·PDF·Word·Excel·기타 파일 입력은 지원하지 않습니다. 디자인 상세 작업은 보류하고 기능을 검증하는 단계입니다.

## 빠른 변환 흐름

1. Finder에서 `.key`, `.ppt`, `.pptx` 파일을 드래그합니다.
2. 드래그 중 **Shift**를 누릅니다. 또는 파일을 노치 근처로 가져갑니다.
3. 커서가 있던 위치에 고정된 원형 메뉴가 펼쳐집니다. Shift를 놓아도 메뉴는 유지됩니다.
4. 파일을 **PDF / JPEG / PNG / PPTX / ZIP** 영역으로 옮겨 놓으면 바로 변환합니다. 가운데나 영역 밖에 놓으면 변환하지 않습니다.
5. 결과는 **원본 파일이 있는 폴더에** 생성됩니다. 완료 창에서 Finder로 결과를 확인할 수 있습니다.

원형 메뉴는 블랙앤화이트로 구성하며 현재 변환 가능한 형식만 활성화합니다. 최초 드래그 분석이 끝나기 전에는 드롭으로 실행할 수 없습니다. 메뉴 막대의 **변환 창 열기**에서는 기존의 파일 선택·저장 폴더 지정 흐름도 사용할 수 있습니다. 이미 변환 중일 때에는 새 드래그 변환을 시작하지 않습니다.

## 지원 범위

| 입력 | PDF | JPEG | PNG | PowerPoint | ZIP |
|---|---|---|---|---|---|
| Keynote .key | Keynote에서 내보내기 | 내보낸 PDF를 슬라이드별 이미지로 | 내보낸 PDF를 슬라이드별 이미지로 | Keynote에서 .pptx로 내보내기 | 원본 압축 |
| PowerPoint .ppt | Keynote에서 내보내기 | 내보낸 PDF를 슬라이드별 이미지로 | 내보낸 PDF를 슬라이드별 이미지로 | Keynote에서 .pptx로 내보내기 | 원본 압축 |
| PowerPoint .pptx | Keynote에서 내보내기 | 내보낸 PDF를 슬라이드별 이미지로 | 내보낸 PDF를 슬라이드별 이미지로 | 원본을 그대로 복사 | 원본 압축 |

- **PowerPoint 출력은 최신 `.pptx`입니다. 구형 `.ppt`는 입력만 지원합니다.**
- JPEG·PNG는 한 슬라이드당 한 파일이며, PDF에서 144 DPI로 렌더링합니다. 매우 큰 슬라이드는 4천만 픽셀 이내로 축소합니다.
- `.key`는 단일 파일과 패키지 폴더 형태를 모두 받습니다. 일반 폴더·외부 파일 링크가 포함된 패키지는 거부합니다.
- PDF/이미지 출력은 1~500슬라이드로 제한합니다. PPTX를 PPTX로 복사하거나 ZIP으로 압축할 때는 원본 내용 그대로 저장합니다.
- ZIP은 선택한 원본을 번호별 하위 폴더에 넣어 압축합니다. Keynote 패키지는 내부 폴더 구조를 유지합니다. 원형 메뉴에서 서로 다른 폴더의 파일을 함께 압축하면 원본 폴더마다 ZIP을 하나씩 만듭니다.
- 여러 입력은 별도로 변환하며 하나의 문서로 합치지 않습니다.
- PPTX 출력은 이미지 슬라이드를 새로 조립하는 방식이 아닙니다. Keynote의 PowerPoint 내보내기를 사용하며, 편집 가능 여부·서식은 Keynote의 호환 범위에 따릅니다.

## 테스트용 설치 파일

배포 방식은 **DMG**입니다. 앱을 응용 프로그램 폴더로 드래그하여 설치합니다. 생성된 앱 안에 Python과 변환 엔진이 포함되므로 테스트 사용자는 **호환 macOS와 Keynote**만 필요합니다.

현재 환경은 Linux이므로 **실제 Mac 앱과 DMG는 아직 생성하지 못했습니다.** 생성 도구와 검증 절차가 포함되어 있습니다. Mac에서 압축을 풀고 `DMG 만들기.command`를 더블 클릭하거나 다음을 실행하세요.

```bash
bash scripts/create-dmg.sh
```

한 번 빌드하는 Mac에는 Python 3.10 이상과 Xcode Command Line Tools가 필요합니다. 빌드 도구는 임시 환경에 설치됩니다. 결과는 `dist/NotchConvert-0.3.0-arm64-test.dmg` 또는 Intel용 `…-x86_64-test.dmg`이며, 이 파일을 다른 테스트 사용자에게 전달합니다. 상세 절차는 `packaging/BUILD-DMG.md`를 확인하세요.

기본 결과물은 ad-hoc 서명된 테스트용 앱이며 Apple 공증은 하지 않습니다. 다운로드한 앱의 실행이 차단되면 시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기를 사용해야 할 수 있습니다.

앱만 빌드하려면 `bash scripts/build-macos.sh`를 실행합니다. 이전 버전과 달리 `~/Library/Application Support/NotchConvert/venv`는 실행에 사용하지 않습니다.

Keynote를 한 번 실행해 초기 안내를 완료해 주세요. 자동화 권한 요청에는 NotchConvert의 Keynote 제어를 허용해야 합니다. 허용하지 않았다면 시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 변경할 수 있습니다. 터미널 검증과 앱 실행은 각각 권한을 요청할 수 있습니다.

Keynote가 없으면 ZIP과 PPTX→PPTX 복사만 표시합니다. 변환 중에는 Keynote가 실행되거나 경고창을 표시할 수 있습니다.

## 원본과 결과

- Keynote는 **임시 복사본**만 열고 닫습니다. 이미 열려 있는 원본 문서를 저장하거나 닫지 않습니다.
- 원형 메뉴는 원본 옆에 결과를 저장합니다. 같은 이름이 있으면 `발표 (2).pdf`처럼 번호를 붙입니다. PPTX→PPTX도 원본을 그대로 두고 새 사본을 만듭니다.
- 일반 변환 창에서 저장 폴더를 직접 선택하면 기존처럼 새 `NotchConvert-…` 폴더에 결과를 만듭니다.
- 긴 파일명은 결과 이름만 줄이고, 번호로 동명 파일을 구분합니다. ZIP 내부의 원본 파일명은 유지합니다.
- 모든 변환이 끝난 후 결과를 저장합니다. 중간 실패 시 임시 출력을 제거합니다. 원본 옆 저장이 실패하면 이번 작업에서 만든 파일만 정리하고 기존 파일을 보존합니다. 하드 링크를 지원하지 않는 외장 드라이브는 덮어쓰지 않는 복사 방식으로 저장합니다.
- Keynote 패키지 내부를 결과 저장 위치로 선택할 수 없습니다.
- 암호 문서·손상 문서·Keynote에서 지원하지 않는 기능이 있는 문서는 실패하거나 사용자 확인이 필요할 수 있습니다. 내보내기 제한 시간은 약 3분입니다.
- 슬라이드 생략 여부·글꼴·애니메이션·전환·영상·발표자 메모는 Keynote의 기본 내보내기 및 호환성에 따릅니다. PDF와 이미지는 정적인 결과입니다. PPT→Keynote→PPTX가 원본 PowerPoint와 완전히 같다는 보장은 없습니다.

## 검증

현재 결과는 `reports/VALIDATION.md`에 기록했습니다. Linux의 처리 흐름 테스트 통과와 Mac의 실제 Keynote 내보내기 통과를 구분합니다.

Mac에서 전체 검증:

```bash
bash scripts/verify-macos.sh
```

이 스크립트는 Swift 앱과 AppleScript를 컴파일하고, 새 테스트 Keynote 문서를 생성한 뒤 **KEY/PPT/PPTX × 5개 출력 = 15개 실제 변환**을 검사합니다. 기존 사용자 문서는 테스트에 사용하지 않습니다. 하나라도 실패하거나 실행되지 않으면 성공으로 처리하지 않습니다. 결과는 `reports/macos.log`와 `reports/matrix-macos.json`에 저장됩니다.

처리 흐름 테스트만 실행하려면:

```bash
python3 -m pip install -r tests/requirements.txt
python3 -m unittest discover -s tests -v
```

이 명령은 기본적으로 실제 Keynote 테스트 15개를 건너뜁니다. 나머지 테스트는 Keynote 호출을 명시적으로 대체하여 저장·압축·렌더링·오류 처리·라우팅을 검사합니다. 실제 Mac 변환 성공의 증거로 사용하면 안 됩니다.

Mac에서 추가로 수동 확인할 항목:

1. Finder에서 KEY/PPT/PPTX를 드래그 → Shift → 원형 메뉴 각 영역 → 드롭 즉시 변환 → 원본 옆 저장.
2. Shift 없이 노치로 드래그, 모서리에서 메뉴 위치 보정, 서로 다른 모니터·음수 좌표에서의 드롭, 중앙/바깥/사용 불가 영역 드롭 취소.
3. Shift를 먼저 누르고 드래그하거나 메뉴가 열린 뒤 Shift를 놓기, Escape로 드래그 취소, 빠른 마우스 해제와 드롭 이벤트 순서.
4. 앱 자동화 권한 허용·거부, Keynote 미설치, 암호 문서, 폰트 누락, 가져오기 경고창.
5. 실제 자료에서 슬라이드 수·한글·표·도형·이미지·글꼴·비율과 PowerPoint/Keynote로 결과 열기.
6. 원본을 Keynote에서 편집 중인 상태에서 변환한 후 원본 창과 미저장 내용이 유지되는지 확인.
7. 노치 없는 화면·외부 모니터·전체 화면·긴 파일명·읽기 전용 폴더.

## 구조

- `Sources/NotchConvert/main.swift`: 메뉴 막대, Shift/노치 드래그 감지, 일반 변환 창.
- `Sources/NotchConvert/RadialMenu.swift`: 5개 부채꼴 메뉴, 드롭 위치 판정과 강조, 화면 경계 보정.
- `Sources/NotchConvert/WorkerClient.swift`: 변환·드래그 분석용 내장 엔진 호출.
- `scripts/create-dmg.sh`: 내장 엔진 포함 앱 빌드, DMG 생성·마운트 검증.
- `scripts/check-worker.py`: 별도 Python 없이 내장 엔진의 재배치·코덱·압축 검사.
- `backend/converter.py`: 입력 검사, Keynote 임시 복사본 처리, PDF 렌더링, ZIP, 원본 보호.
- `backend/export-keynote.applescript`: Keynote 네이티브 PDF/PPTX 내보내기.
- `tests/test_presentations.py`: 플랫폼 공통 처리 흐름과 오류 테스트.
- `tests/test_keynote_native.py`: 실제 Mac 전용 15개 변환 테스트.
- `tests/fixtures/legacy.ppt`: 직접 생성한 구형 PowerPoint 테스트 파일, 2슬라이드.
