# Whisper 글꼴 적용

2026-10-05: 사용자가 선택·설치한 **교보 손글씨 2019**를 앱과 최신 App Store 이미지 두 시안에 적용한다.

## 앱

- 손글씨 제목, 일기 제목·본문, 사진 설명, 기록 내용 미리보기: 교보 손글씨 2019 Regular.
- 버튼, 설정, 일반 안내, 날짜 메타데이터: 기존 Noto Sans KR.
- 기존 손글씨로 강조하던 감정 선택 제목, 홈 날짜 제목, 달력의 월 제목도 같은 교보 글꼴을 쓴다.
- 일기 본문 기본 18pt. SwiftUI의 `relativeTo: .body`와 UIKit의 `UIFontMetrics`를 통해 Dynamic Type을 유지한다.
- 손글씨는 한 가지 굵기만 제공되므로 합성 Bold 없이 크기로 위계를 만든다.
- `Font+Whisper.swift`의 `WhisperTypography`에서 PostScript 이름과 본문 크기를 관리한다.
- `UIAppFonts`에 `KyoboHandwriting2019.otf`를 등록했다. 원본 파일의 이름·형식·내용을 변경하지 않았다.
- 이전 Gaegu 파일은 이전 디자인 소스 재생성을 위해 보존했으며 앱의 등록 목록에서는 제외했다.

## 검증

2026-10-11 커밋 검증: 글꼴 변경만 분리한 소스에서 `WhisperTypographyTests`와 `DiaryTextViewTests`를 실행했습니다. iPhone 17 Pro / iOS 26.5와 iPad Pro 13-inch (M5) / iPadOS 27.0에서 각각 6개 테스트가 통과했습니다. 앱에 등록된 글꼴, 한글 11,172자의 실제 윤곽, 읽기·편집 화면의 글꼴과 사진·본문·초안 보존을 확인했습니다. 로그: `/tmp/whisper-typography-commit-tests.log`.

- 앱에 등록된 실제 `UIFont`의 이름이 `KyoboHandwriting2019`인지 검사했다.
- 한글 완성형 U+AC00…U+D7A3의 11,172자 모두 glyph mapping과 비어 있지 않은 실제 윤곽이 있는지 검사했다. 단순 매핑만으로 지원 여부를 판단하지 않는다.
- 읽기·작성 화면의 실제 `UITextView` 본문이 교보 손글씨로 렌더되는지 검사했다.
- 작성·읽기·사진 편집·초안 보존 관련 기존 검사와 글꼴 검사를 포함한 11개 테스트가 통과했다. 로그: `/tmp/whisper-kyobo-regression.log`.
- 별도 캡처 프로젝트에서 iPhone 실제 화면 6장을 생성했고 캡처·글꼴 테스트 2개가 통과했다. 로그: `/tmp/whisper-appstore-kyobo.log`.
- 긴 예시 일기 본문과 사진 설명이 잘리지 않고 보이는지 캡처를 직접 확인했다.

## App Store 이미지

`AppStore/iPhone-Reference-v2`와 `AppStore/iPhone-OurDay-v3`는 새 앱 캡처를 사용한다. 홍보 문구·워드마크도 교보 손글씨 2019, 작은 설명은 Noto를 유지했다. 상태바는 Apple iOS 라이브러리 에셋을 사용한다. OurDay 참고 시안은 기존 여백과 기기 위치를 살리면서 홍보 문구를 86/94px로 조정했다.

각 시안의 PNG 6장은 1320 × 2868px, 8-bit RGB sRGB, 알파 없음이다. ZIP에는 해당 PNG만 포함한다. SVG의 홍보 문구·목업은 편집용 레이어이며, 앱 화면 내부는 실제 캡처 이미지다.

## Figma 반영 및 저장 상태

- 기존 `31 최신안`(10553:1529)과 `32 비교안`(10555:3028) 프레임 안의 카드 6장씩을 갱신했다. 두 프레임의 ID·위치·크기는 유지했다.
- SVG 가져오기 시 비어 있던 교보 텍스트 레이어를 네이티브 Figma에서 복구하고, 줄 간격과 기준선 위치를 맞췄다. 홍보 문구는 편집 가능한 텍스트다.
- 각 시안의 `Review/figma-board-proof.png`에 실제 편집 화면을 보관했다.
- Figma 연결 복구 후 최근 파일 목록에서 원본 Whisper를 다시 열었다. 연결 오류와 미저장 알림이 사라졌고 두 시안의 글꼴·배치·캡처가 보존된 것을 확인했다.
- **글꼴 변경 당시 서버 동기화 확인 완료**: 별도의 웹 세션에서 원본 파일을 새로 불러와 일기 본문, 고양이 사진, 바다 사진과 확대 카드를 확인했다. 초기에 검게 보이던 캡처도 정상적으로 표시된다. 웹 검수 화면은 OurDay 시안의 `Review/figma-server-diary-proof.png`와 `Review/figma-server-photo-proof.png`에 보관했다.
- 완성 문서를 `AppStore/Whisper-Kyobo-AppStore.fig`로 저장했다. 원본 Whisper 파일의 다른 페이지도 포함된 로컬 복사본이다.

이후 OurDay 레이아웃 수정: 감정·사진·검색창의 확대 레이어 세 개를 Figma에서 숨겼다. 실제 앱 캡처 안의 내용을 그대로 보이게 했고 PNG·SVG·ZIP도 같은 구성으로 재생성했다. `Review/figma-board-proof.png`는 이 수정 후 화면이다. `.fig` 로컬 복사본과 이전 서버 검수 이미지는 확대 레이어를 숨기기 전 버전이다.

서체 출처와 이용조건은 `Whisper/Fonts/KyoboHandwriting2019-LICENSE.txt`에 기록했다.

2026-10-05 iOS 에셋 갱신: PNG/ZIP의 기기 외곽·상태바·홈 인디케이터는 Apple iOS and iPadOS 27 라이브러리 에셋이다. Figma 31·32 보드에도 같은 에셋을 적용했고, 2026-10-06 모든 카드의 표시를 확인했다. 기존 `.fig` 백업과 서버 검수 이미지는 이 갱신 이전 버전이다. `Review/figma-board-proof.png`는 iOS 에셋 및 새 배경 적용 후의 네이티브 검수 화면이다. 현재 서버 동기화는 대기 중이다.

2026-10-06: App Store 두 시안의 배경을 크림색→살구색 그라데이션과 곡선으로 갱신했다. 글꼴과 앱 화면은 유지했다. 최신 전체 문서 백업은 `AppStore/Whisper-AppStore-Paper-20261006.fig`이며, Figma 앱은 일부 변경 사항의 서버 동기화 대기를 표시한다.
