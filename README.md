# 코디세이 맥 초기 설정

매번 초기화되는 교육용 Mac에서 아래 두 설정을 한 번에 적용하는 파일입니다.

1. macOS 기본 **한국어 두벌식 입력기** 추가
2. **Spotlight의 Command-Space 단축키** 해제

관리자 암호나 별도 앱 설치는 요구하지 않습니다. 같은 파일을 다시 실행해도 한글 입력기를 중복으로 추가하지 않습니다.

## 1. GitHub에 한 번 올려두기

1. GitHub에서 새 저장소를 만듭니다.
2. 저장소 이름은 `codyssey-mac-setup`으로 지정합니다.
3. 가장 간단하게 쓰려면 저장소 공개 범위를 **Public**으로 선택합니다.
4. 이 폴더 안의 `setup.command`와 `README.md`를 저장소의 최상위 위치에 업로드합니다.
5. `Commit changes`를 누릅니다.

이 파일에는 비밀번호나 API 키 같은 비밀 정보가 들어 있지 않습니다.

## 2. 초기화된 Mac에서 실행하기

터미널을 열고 아래 한 줄을 붙여넣습니다.

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_ID/codyssey-mac-setup/main/setup.command -o /tmp/codyssey-setup.command && /bin/bash /tmp/codyssey-setup.command
```

`YOUR_GITHUB_ID`만 본인의 GitHub 아이디로 바꿉니다.

```bash
curl -fsSL https://raw.githubusercontent.com/julieeeee2/codyssey-mac-setup/main/setup.command -o /tmp/codyssey-setup.command && /bin/bash /tmp/codyssey-setup.command
```

이 명령은 GitHub의 파일을 임시 폴더에 내려받은 뒤 바로 실행합니다. 실행이 끝나면 터미널에 적용 결과가 표시됩니다.

> 보안을 위해 주소가 본인의 GitHub 저장소를 가리키는지 확인한 뒤 실행하세요.

## 파일을 직접 내려받아 실행하는 방법

1. GitHub에서 `setup.command`를 내려받습니다.
2. 터미널에서 아래 명령을 실행합니다.

```bash
cd ~/Downloads
chmod +x setup.command
./setup.command
```

브라우저로 받은 실행 파일은 macOS 보안 경고가 생길 수 있으므로, 매번 쓰기에는 앞의 `curl` 한 줄 방식이 더 단순합니다.

## 작동 방식

- Command Line Tools가 있으면 macOS의 Text Input Source Services API로 한국어 입력기를 활성화합니다.
- 개발 도구가 없으면 `com.apple.HIToolbox` 사용자 설정에 두벌식 입력기를 추가합니다.
- Spotlight의 `Command-Space` 항목만 비활성화하며, Spotlight 검색 기능이나 인덱싱 자체는 끄지 않습니다.
- 실행 중 열려 있는 시스템 설정 앱은 캐시 충돌을 막기 위해 닫힐 수 있습니다.
- 변경 전 설정은 다음 폴더 아래에 백업합니다.

```text
~/Library/Application Support/CodysseyMacSetup/backups/
```

## 적용이 바로 안 보일 때

메뉴 막대의 입력기 목록이 즉시 갱신되지 않는 macOS 버전에서는 한 번 로그아웃 후 로그인합니다. 교육기관의 MDM 관리 정책이 사용자 키보드 설정을 강제로 되돌리는 경우에는 다음 로그인이나 초기화 뒤에 스크립트를 다시 실행해야 합니다.
