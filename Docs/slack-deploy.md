# Slack으로 Whisper 배포하기

`/testflight`는 `dev`의 새 빌드를 **내부 TestFlight 그룹**에 배포합니다. `/testflight main`으로 `main`을 선택할 수도 있습니다. `/review 2.0.1 42`는 **이미 업로드된 2.0.1의 42번 빌드**를 App Store 심사에 제출합니다. 심사 통과 후 출시는 수동입니다.

```text
Slack Slash Command → Cloudflare Worker → GitHub Actions → fastlane → App Store Connect
                                              └→ Slack 시작·완료·실패 알림
```

현재 구현 대상은 `Youngmin322/whisper`, 기본 브랜치 `dev`, Bundle ID `co.kr.youngmin.Whisper`, Apple Team `5R33532VPH`입니다. 외부 테스터 배포는 포함하지 않습니다.

## 1. GitHub에 워크플로 등록

이 변경을 기본 브랜치 `dev`에 반영합니다. GitHub Actions의 **Slack deploy**가 표시되는지 확인하세요. 아직 반영하지 않았다면 Slack 명령으로 실행할 수 없습니다.

앱 소스는 선택한 `dev` 또는 `main` 브랜치에서, 배포 도구는 Worker의 `GITHUB_WORKFLOW_REF`(`dev`)에서 가져옵니다. 실행 시점의 브랜치 HEAD를 빌드하며, 실제 commit은 완료 알림에 표시됩니다. 브랜치의 기존 `Scripts/test-ios.sh` 테스트가 통과해야 업로드를 시작합니다.

## 2. App Store Connect와 서명 설정

App Store Connect에서 Whisper의 **내부 테스트 그룹**을 만들고 팀의 테스터를 추가합니다. 그룹 이름을 GitHub 저장소 → Settings → Secrets and variables → Actions → **Variables**에 등록합니다.

| Variable | 값 |
| --- | --- |
| `TESTFLIGHT_INTERNAL_GROUP` | 실제 내부 그룹 이름 (예: `Whisper Internal`) |
| `IOS_USES_NON_EXEMPT_ENCRYPTION` | 기존 앱의 수출 규정 답변에 맞는 `true` 또는 `false` |

암호화 답변은 기존 App Store Connect 설정과 앱이 사용하는 암호화 기능을 확인해 정합니다. 이 값은 TestFlight의 빌드 처리에 필요합니다.

이 구성은 **Whisper만 접근할 수 있는 사용자의 개별 API 키**를 사용합니다. 계정 설정과 키 등록은 본인이 사용하는 브라우저·터미널에서 직접 진행합니다. 비밀번호·인증번호·키 파일이나 계정 전체 화면을 공유할 필요는 없습니다.

1. 기존 소유자 계정의 Users and Access → People에서 별도 사용자를 추가합니다. 역할은 **App Manager**, 앱 접근은 **Whisper만** 선택합니다. 보고서와 Certificates, Identifiers & Profiles 접근 권한은 추가하지 않습니다. 이미 같은 제한이 적용된 사용자가 있다면 그 사용자를 사용할 수 있습니다.
2. 해당 사용자에게 Additional Resources → **Generate Individual API Keys**가 허용되어 있는지 확인합니다. 이 권한이 없으면 프로필에 키 생성 버튼이 보이지 않습니다.
3. 제한된 사용자 계정으로 초대를 수락하고 로그인한 뒤 사용자 이름 → Edit Profile → Individual API Key에서 키를 발급합니다. Key ID를 확인하고 `.p8`를 안전한 위치에 보관합니다. 키는 한 번만 다운로드할 수 있습니다.
4. 아래 명령을 본인의 터미널에서 실행해 Key ID와 `.p8`의 base64 값을 GitHub Secrets에 직접 등록합니다. 개별 키에는 **Issuer ID가 없으므로 ASC_ISSUER_ID는 등록하지 않습니다**. 배포 인증은 개별 키로 고정되며, 세 가지 기존 issuer 환경 변수(ASC_ISSUER_ID, APP_STORE_CONNECT_API_KEY_ISSUER_ID, SPACESHIP_CONNECT_API_ISSUER_ID)가 설정되어 있으면 팀 키 인증으로 전환하지 않고 오류로 중단합니다.

키의 실제 앱 접근 범위는 Apple의 사용자 설정이 결정합니다. 팀 키는 역할과 무관하게 모든 앱에 적용되고, 소유자 계정의 개별 키도 소유자의 넓은 접근 권한을 상속합니다. 코드의 Whisper 앱 ID 검사는 유출된 키 자체의 권한을 제한하지 못하므로 키를 만들 사용자의 앱 범위를 먼저 확인합니다. [Apple API 키 권한 안내](https://developer.apple.com/documentation/AppStoreConnectAPI/creating-api-keys-for-app-store-connect-api), [사용자 앱 접근 제한](https://developer.apple.com/help/app-store-connect/manage-your-team/edit-access-to-apps/), [fastlane 개별 키 인증](https://docs.fastlane.tools/actions/app_store_connect_api_key/)

개별 키는 Provisioning API를 사용할 수 없습니다. 기존 소유자 계정에서 이 앱·팀에 맞는 **App Store Connect 배포용 provisioning profile**을 별도로 준비하고, 그 프로필과 일치하는 Apple Distribution 인증서와 개인 키를 암호가 있는 `.p12`로 내보냅니다. CI는 준비된 파일을 사용하며 인증서·프로필을 API로 생성하지 않습니다.

키는 GitHub Actions Secrets에 보관하되, 실행 중인 workflow는 값을 사용할 수 있으므로 배포 workflow와 실행 브랜치를 수정할 수 있는 사람도 신뢰할 수 있어야 합니다. 키가 유출되면 Apple에서 즉시 폐기합니다.

아래 값은 GitHub 저장소 → Settings → Secrets and variables → Actions의 **Secrets**에 직접 등록합니다. 파일·비밀 값은 채팅이나 Git에 붙여 넣지 않습니다.

| Secret | 내용 |
| --- | --- |
| `ASC_KEY_ID` | 제한된 사용자의 개별 API Key ID |
| `ASC_KEY_P8_BASE64` | `.p8` 파일을 base64로 인코딩한 값 |
| `IOS_DISTRIBUTION_P12_BASE64` | 인증서와 개인 키가 들어 있는 `.p12`의 base64 |
| `IOS_DISTRIBUTION_P12_PASSWORD` | `.p12` 내보내기 암호 |
| `IOS_APPSTORE_PROFILE_BASE64` | `.mobileprovision` 파일의 base64 |
| `SLACK_DEPLOY_WEBHOOK_URL` | 다음 단계에서 발급할 Slack Incoming Webhook URL |

파일 값은 Mac 터미널에서 바로 등록할 수 있습니다. 경로는 실제 파일 경로로 바꿉니다.

```sh
base64 -i /absolute/path/AuthKey.p8 | gh secret set ASC_KEY_P8_BASE64 --repo Youngmin322/whisper
base64 -i /absolute/path/Distribution.p12 | gh secret set IOS_DISTRIBUTION_P12_BASE64 --repo Youngmin322/whisper
base64 -i /absolute/path/AppStore.mobileprovision | gh secret set IOS_APPSTORE_PROFILE_BASE64 --repo Youngmin322/whisper
gh secret set ASC_KEY_ID --repo Youngmin322/whisper
gh secret set IOS_DISTRIBUTION_P12_PASSWORD --repo Youngmin322/whisper
```

서명 파일은 runner의 임시 폴더와 임시 키체인에만 설치하고 lane 종료 시 정리합니다. 매번 App Store Connect에서 해당 버전의 최근 TestFlight 빌드번호를 조회해 1을 더합니다. 같은 번호의 중복 업로드를 피하도록 배포 작업은 직렬화합니다. 별도 로컬 업로드와는 번호를 조율해야 합니다. GitHub 기본 concurrency 동작상 실행 중인 작업 하나와 대기 작업 하나가 유지되므로 연속 요청 시 이전 대기 작업은 취소될 수 있습니다.

## 3. Cloudflare Worker 준비

[Cloudflare 계정](https://dash.cloudflare.com/sign-up)을 만들고 **가입 이메일 인증까지 완료**합니다. 메일 링크를 연 뒤 같은 계정으로 로그인합니다. 인증 전에는 Worker 배포가 `10034` 오류로 거부됩니다. 메일이 없으면 대시보드의 **Resend verification email**로 재전송하고 스팸함을 확인합니다. [공식 이메일 인증 안내](https://developers.cloudflare.com/fundamentals/user-profiles/verify-email-address/)를 참고하세요.

Workers **Free** 플랜으로 시작하며 별도 도메인 없이 `workers.dev` 주소를 사용합니다. 실제 iOS 빌드는 GitHub Actions의 macOS runner를 사용하므로 첫 실행 전에 GitHub Billing에서 포함 사용량과 예산을 별도로 확인합니다.

```sh
cd Services/slack-deploy
npm ci
npx wrangler login --device --scopes account:read user:read workers_scripts:write
npm run deploy
```

출력된 Worker URL을 기록합니다. `/health`는 `{"ok":true}`를 반환합니다. 처음에는 Slack ID와 비밀 값이 없으므로 명령 실행은 거부합니다. Slack 서명 키와 허용 ID를 연결하면 GitHub 토큰을 등록하기 전에도 `help`는 응답합니다. 이때 실제 배포 명령은 연결 미완료 안내만 반환하며 Actions를 실행하지 않습니다.

Wrangler 로그인 승인 화면에서는 계정·사용자 읽기, **Workers Scripts Write**, 로그인 유지 권한을 확인하고 승인합니다. 일반 `workers:write`만으로는 Worker 배포 API에 접근할 수 없습니다. 기기 인증 방식은 `localhost` 콜백을 사용하지 않습니다. CLI에 표시된 유효 시간 안에 승인을 완료하며, 만료됐다면 로그인 명령을 다시 실행합니다. 유료 플랜 신청은 이 단계에 포함되지 않습니다.

## 4. Whisper 워크스페이스에 Slack 앱 설치

1. [Slack Your Apps](https://api.slack.com/apps)에 Whisper 계정으로 로그인하고 **Create an App → From a manifest**를 선택합니다.
2. `Services/slack-deploy/slack-app-manifest.json`을 에디터의 기존 내용 전체와 교체합니다. 두 명령의 `url`이 본인의 Worker URL + `/slack/commands`인지 확인하고 **Whisper** 워크스페이스를 선택합니다. manifest의 `bot_user`는 Slack이 bot scope 검증에 요구하는 표시 설정입니다.
3. **Next**에서 권한이 `commands`, `incoming-webhook`인지 검토하고 **Create and Install**로 설치합니다. 배포 알림 채널을 선택하고 Incoming Webhooks에서 URL을 확인합니다.
4. 그 URL을 GitHub의 `SLACK_DEPLOY_WEBHOOK_URL` secret에 등록합니다. 이 채널에서 시작·완료·실패 알림을 받습니다.
5. Basic Information에서 **Signing Secret**을 확인합니다. Cloudflare Worker secret에 직접 등록합니다.

```sh
npx wrangler secret put SLACK_SIGNING_SECRET
```

## 5. Slack 권한과 GitHub 실행 토큰 연결

`Services/slack-deploy/wrangler.jsonc`의 값을 채웁니다. 이름 대신 **ID**를 사용합니다.

| 설정 | 찾는 곳 |
| --- | --- |
| `SLACK_TEAM_ID` | 브라우저 Slack 주소 `app.slack.com/client/T…/C…`의 `T…` |
| `SLACK_ALLOWED_USER_IDS` | 본인 Slack 프로필 → 더 보기 → 멤버 ID 복사. 여러 명이면 쉼표 구분 |
| `SLACK_ALLOWED_CHANNEL_IDS` | 사용할 채널 세부정보의 채널 ID. 여러 채널이면 쉼표 구분 |

GitHub에서 **이 저장소 하나만 선택한 fine-grained token**을 만들고 Repository permissions → **Actions: Read and write**를 부여합니다. 토큰은 Worker에만 저장하며, Slack이나 저장소 파일에는 넣지 않습니다. 토큰이 만료되면 교체해야 합니다.

```sh
npx wrangler secret put GITHUB_TOKEN
npm run deploy
```

Slack 서명·요청 시각·워크스페이스·사용자·채널을 모두 검사한 뒤에만 실행합니다. 허용 브랜치는 Worker와 GitHub workflow 양쪽에서 `dev`, `main`으로 제한합니다. Slack 명령 접수는 즉시 응답하고 GitHub 접수 결과는 별도 응답으로 알립니다. 실제 작업의 결과는 Incoming Webhook 채널로 보냅니다.

## 6. 첫 실행

먼저 `/testflight help`로 명령 연결을 확인합니다. 이후 `/testflight`를 실행하고, GitHub 접수 응답 → 채널 시작 알림 → Actions 테스트·아카이브·업로드 → 채널 완료 알림 → TestFlight 내부 그룹의 새 빌드를 확인합니다. 완료 알림에는 버전·빌드번호·소스 commit이 표시됩니다.

정식 심사는 App Store Connect에서 해당 버전의 설명·스크린샷·개인정보·심사 연락처·출시 노트 등 필수 정보를 먼저 준비합니다. 그 뒤 `/review 버전 빌드번호`를 실행합니다. 기존 메타데이터를 사용하며, 실패 시 Actions 로그에서 누락된 항목을 확인합니다. 제출 성공과 Apple의 심사 승인은 다른 상태입니다.

GitHub 접수 확인이 실패한 경우 중복 요청 전에 Actions 실행 목록을 확인하세요. Slack 재전송 헤더가 있는 요청은 중복 실행하지 않습니다. 완전한 영속 큐·재시도 시스템은 포함하지 않습니다.

## 로컬 검증

```sh
node --test Services/slack-deploy/test/*.test.js Scripts/notify-slack.test.mjs
ruby fastlane/deploy_config_test.rb
ruby -c fastlane/Fastfile
cd Services/slack-deploy
npm ci
npx wrangler deploy --dry-run --outdir /tmp/whisper-slack-worker
```

단위 테스트는 GitHub·Slack 요청을 대체해 인증·권한·입력·비동기 접수·실패 알림을 검증합니다. 실제 서명·Apple 업로드·Slack 설치까지 성공했다는 의미는 아닙니다.

공식 문서: [Slash Commands](https://docs.slack.dev/interactivity/implementing-slash-commands/), [Slack 서명 검증](https://docs.slack.dev/authentication/verifying-requests-from-slack/), [GitHub workflow dispatch](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event), [Cloudflare secrets](https://developers.cloudflare.com/workers/configuration/secrets/), [fastlane TestFlight](https://docs.fastlane.tools/actions/upload_to_testflight/), [fastlane 심사 제출](https://docs.fastlane.tools/actions/upload_to_app_store/).

## 업로드 후 그룹 연결 오류 복구

업로드가 성공한 뒤 `Cannot add internal group to a build`가 발생하면 `/testflight`를 다시 실행하기 전에 기존 빌드를 확인합니다. 자동 배포 그룹에는 수동 연결 요청을 보내지 않고, 수동 그룹에서 같은 오류가 발생해도 정확한 빌드가 처리 완료·내부 테스트 가능 상태이며 지정 그룹의 빌드 목록에 실제로 포함된 경우에만 성공으로 처리합니다. 그 외 API 오류는 그대로 실패합니다.

이미 업로드된 빌드는 GitHub Actions의 **Slack deploy → Run workflow**에서 `operation=finish_testflight`, 정확한 `version`과 `build_number`를 지정해 배포를 마무리할 수 있습니다. 이 경로는 앱을 다시 빌드하거나 업로드하지 않으며 서명 인증서도 사용하지 않습니다. 기존 빌드의 내부 그룹 접근을 확인한 뒤 Slack에 결과를 알립니다. App Store 심사 제출은 실행하지 않습니다.
