# Whisper

순간의 글과 사진을 남기고 하루의 일기로 모으는 iOS 앱입니다.

## 개발 환경

- Xcode 26 이상(Swift 6.2 이상)
- iOS 26 이상
- 테스트용 iOS 26 이상 iPhone 시뮬레이터

`WhisperCore`와 `WhisperDesignSystem`은 저장소 내부의 `Packages/WhisperCore`에 포함되어 있습니다. 이 저장소만 클론한 뒤 `Whisper.xcodeproj`를 열면 빌드할 수 있습니다.

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
