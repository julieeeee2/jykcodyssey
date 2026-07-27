# 코디세이 맥 초기 설정 v2

매번 초기화되는 교육용 Mac에서 아래 설정을 한 번에 적용합니다.

1. macOS 기본 **한국어 두벌식 입력기** 추가
2. **fn/지구본 키**를 `Change Input Source`로 설정
3. **Caps Lock 키를 fn/지구본 키로 변환**하여 Caps Lock으로 한/영 전환
4. **Spotlight의 Command-Space 단축키 유지**

관리자 암호나 별도 앱 설치는 요구하지 않습니다.

## 달라지는 점

Caps Lock 키는 한/영 전환 전용으로 사용됩니다. 따라서 Caps Lock의 원래 고정 대문자 기능은 사용할 수 없고, 영문 대문자는 `Shift`를 누른 채 입력합니다.

Spotlight는 기존처럼 `Command-Space`로 열립니다.

## 파일을 내려받아 실행하기

1. GitHub에서 `setup.command`를 다운로드합니다.
2. **터미널**을 엽니다.
3. 터미널에 `bash`와 공백 하나를 입력합니다.

```bash
bash 
```

4. 다운로드한 `setup.command` 파일을 터미널 창으로 드래그합니다.
5. Enter를 누릅니다.

화면에는 대략 다음처럼 표시됩니다.

```bash
bash /Users/사용자이름/Downloads/setup.command
```

브라우저에서 받은 서명되지 않은 `.command` 파일은 macOS가 더블클릭 실행을 막을 수 있습니다. 위처럼 Bash로 실행하면 실행 권한 설정이나 Gatekeeper 전체 해제가 필요하지 않습니다.

## GitHub에서 한 줄로 바로 실행하기

저장소를 Public으로 만든 뒤 아래 명령의 `YOUR_GITHUB_ID`만 본인의 GitHub 아이디로 바꿉니다.

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_ID/codyssey-mac-setup/main/setup.command -o /tmp/codyssey-setup.command && /bin/bash /tmp/codyssey-setup.command
```

이 명령은 GitHub의 파일을 임시 폴더에 내려받은 뒤 Bash로 실행합니다. 주소가 본인의 저장소를 가리키는지 확인한 뒤 실행하세요.

## 작동 방식

- Command Line Tools가 있으면 macOS의 Text Input Source Services API로 한국어 입력기를 활성화합니다.
- 개발 도구가 없으면 `com.apple.HIToolbox` 사용자 설정에 두벌식 입력기를 추가합니다.
- `AppleFnUsageType=1`을 저장하여 fn/지구본 키를 입력 소스 변경으로 설정합니다.
- macOS 기본 명령인 `hidutil`로 현재 로그인 세션에서 Caps Lock을 fn/지구본 키로 바꿉니다.
- Spotlight의 `Command-Space` 항목은 활성 상태로 둡니다.
- 변경 전 설정은 다음 폴더 아래에 백업합니다.

```text
~/Library/Application Support/CodysseyMacSetup/backups/
```

## 적용이 바로 안 보일 때

대부분은 실행 직후 Caps Lock으로 한/영 전환할 수 있습니다. fn/지구본 키 설정만 즉시 반영되지 않는 macOS에서는 한 번 로그아웃했다가 로그인한 후 스크립트를 다시 실행합니다.

Caps Lock 변환은 재시동하면 해제됩니다. 코디세이 Mac이 초기화되거나 재시동된 뒤에는 이 파일을 다시 실행하면 됩니다.
