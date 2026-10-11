# Whisper

순간의 글과 사진을 남기고 하루의 일기로 모으는 iOS 앱입니다.

## 개발 환경

- Xcode 26 이상(Swift 6.2 이상)
- iOS 26 이상
- 테스트용 iOS 26 이상 iPhone 시뮬레이터

앱 코드와 디자인 시스템은 `Whisper/`에 함께 있습니다. 이미지·색상은 `Whisper/Assets.xcassets`, 글꼴은 `Whisper/Fonts`에서 관리합니다. 별도 Swift 패키지 없이 `Whisper.xcodeproj`를 열면 빌드할 수 있습니다.

## 표시 언어

현재 앱의 지원 언어와 기본 언어는 한국어(`ko`)이며, 다른 기기 언어에서도 한국어로 폴백합니다. 프로젝트의 `developmentRegion`·`knownRegions`와 `Whisper/Info.plist`의 `CFBundleLocalizations`를 일치시켜 시스템 검색 안내와 취소 동작도 앱의 언어를 따르게 합니다.

다국어 지원은 [#44](https://github.com/Youngmin322/whisper/issues/44)에서 진행합니다. 언어를 추가할 때는 번역 리소스와 지원 언어 선언을 함께 반영하고, 시스템 검색 안내도 실제 빌드된 앱에서 확인합니다.

## 작성 중인 기록

‘순간 남기기’는 기존 초안과 별개로 항상 새 글을 시작합니다. 닫은 순간 초안은 각각 보관되며, 홈의 ‘작성 중인 기록 이어 쓰기’에서 선택해 계속 작성할 수 있습니다. 글·사진·감정은 초안별로 유지되고, 한 초안을 저장하거나 버려도 다른 초안은 남습니다.

## 검증

```sh
bash Scripts/test-ios.sh
```

설치된 iPhone 시뮬레이터를 자동 선택합니다. 특정 기기는 `WHISPER_SIMULATOR_ID`, 빌드 경로는 `WHISPER_DERIVED_DATA` 환경 변수로 지정할 수 있습니다. 추가 `xcodebuild` 인자는 스크립트 뒤에 전달합니다.

서명 없이 Release 아카이브를 검증하려면:

```sh
xcodebuild archive \
  -project Whisper.xcodeproj -scheme Whisper \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/whisper-release \
  -archivePath /tmp/Whisper.xcarchive \
  CODE_SIGNING_ALLOWED=NO
```

배포용 아카이브는 Xcode에서 서명 설정과 버전을 확인한 뒤 생성합니다. 배포 전 실기기에서 기존 기록·사진 유지, 초안 이어 쓰기, 수정·삭제와 일기 복구, 접근성 글자 크기 및 VoiceOver를 확인하세요.
