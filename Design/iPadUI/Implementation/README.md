# Whisper iPad 네이티브 구현

2026-10-07. 기존 [Figma 시안](https://www.figma.com/design/dBVQ07i18D0BAlhU4qreuX/Whisper?node-id=10598-1210)을 SwiftUI로 구현했다. 이후 논의한 대로 홈에 일기를 상시 표시하지 않으며, 화면의 역할에 따라 읽기·쓰기·탐색을 배치한다.

## 동작

- 홈은 오늘의 불꽃 공간을 사용한다. 불꽃을 선택할 때만 시스템 inspector에서 그 순간을 읽으며, 닫으면 전체 공간으로 돌아간다.
- 시스템 사이드바에서 홈, 보관함, 기억 찾기, 설정으로 이동한다. 좁은 iPad 창에서도 iPhone 화면으로 교체하지 않는다.
- 순간 작성은 넓은 창에서 감정 선택과 본문을 나란히 표시한다. 좁은 창이나 접근성 글자 크기에서는 감정 선택을 본문 위에 배치한다.
- 일기 작성은 넓은 창에서 원본 순간을 참고하며 한 편의 본문을 편집한다. 좁은 창에서는 원본 목록을 접는다.
- 보관함과 검색은 기록을 선택한 뒤에만 읽기 영역을 표시한다. 좁은 창에서는 목록에서 상세로 이동하고, 창을 다시 넓히면 같은 선택을 분할 화면에서 이어 본다.
- 검색어·선택 날짜·선택 기록은 워크스페이스가 보관한다. 검색어가 바뀌어 선택 기록이 결과에서 빠지면 읽기 영역을 비운다.
- 작성 화면은 닫거나 앱이 비활성화될 때 초안을 보관한다. 저장은 기존 RecordStore의 트랜잭션을 사용하며, 순간 원본·일기 사진 스냅샷·초안 복구 규칙을 유지한다.
- 저장은 상단 네이티브 툴바에 둔다. 외부 키보드의 Command-N과 Command-S를 지원한다.

## iPhone과의 분리

`ContentView.swift`의 기기 분기에서 iPad에만 `IPadWorkspaceView`를 연결한다. iPhone의 기존 HomeView, QuickRecordView, JournalEditorView, 보관함·검색 화면은 이번 구현에서 수정하지 않았다. 기존에 수정 중이던 글꼴·편집기·프로젝트 설정 변경도 이번 커밋에 포함하지 않았다.

신규 화면은 `Whisper/iPad/`에 있다. 공통 데이터 모델, SwiftData 스키마, 저장소, 마이그레이션은 변경하지 않았다. DiaryTextView, PhotoAttachmentLoader, 불꽃 자산과 움직임, 색상·글꼴 토큰은 기존 구현을 재사용한다.

## 검증

- iPad Pro 11-inch (M5), iPadOS 27.0: iPad 통합 테스트 6개 통과. 네이티브 텍스트 입력, 창 크기 변경 시 편집기 유지, 사진의 UTF-16 위치, 초안 복원, 원본 보존, 시간대 변경 시 출처 중복 제외, 선택과 검색 갱신을 확인했다.
- iPhone 17 Pro, iOS 26.5: 기존 테스트 기기와 새 회귀 검증 기기에서 전체 테스트 158개 통과. 새 기기의 첫 실행에서 기존 키보드 포커스 검사가 한 번 실패했으며, 해당 5개 검사와 전체 158개 재실행은 모두 통과했다.
- 실제 실행한 iPad 앱에서 순간 저장 → 불꽃 선택과 상세 닫기 → 순간을 일기로 모아 저장 → 보관함에서 본문과 원본 확인까지 완료했다.
- 1194 × 834, 834 × 1194, 600 × 834와 접근성 글자 크기에서 UIKit/SwiftUI 렌더를 캡처해 검토했다.
- 실기기의 키보드·멀티태스킹·VoiceOver와 기존 설치 데이터는 추가 확인이 필요하다.

기존 iPhone 테스트 기기의 앱 초기화에는 이전 저장소의 알 수 없는 모델 버전 오류가 기록되었다. 저장소와 마이그레이션 코드가 이번 변경 전후 동일하므로 해당 저장소는 수정하거나 삭제하지 않았다. 통합 테스트는 별도의 메모리·테스트 저장소를 사용한다.

## 캡처

`IPadNavigationViewTests.captureResponsiveScreens`가 생성한 실제 네이티브 렌더다. 본문 사진은 테스트용 이미지이며 실제 앱에서는 사용자가 첨부한 사진을 표시한다.

| 파일 | 화면 |
| --- | --- |
| 01-home-landscape.png | 사이드바와 불꽃 홈 |
| 02-moment-landscape.png | 감정 선택과 순간 작성 |
| 03-moment-narrow.png | 좁은 창의 순간 작성 |
| 04-journal-landscape.png | 원본 순간과 일기 작성 |
| 05-journal-portrait.png | 세로 일기 작성 |
| 06-archive-landscape.png | 날짜별 기록과 선택한 일기 |
| 07-search-landscape.png | 검색 결과와 선택한 일기 |
| 08-moment-accessibility.png | 큰 글자의 순간 작성 |
| 09-home-portrait.png | 세로 홈 |
| 10-home-narrow.png | 좁은 창의 홈 |

```sh
WHISPER_SIMULATOR_ID=<iPad 시뮬레이터 UUID> bash Scripts/test-ios.sh \
  -only-testing:WhisperTests/IPadNavigationViewTests \
  -only-testing:WhisperTests/IPadWritingViewTests

bash Scripts/test-ios.sh
```

원래 Figma 보드의 시안과 로컬 `.fig`는 유지했다. 앱 구현에는 위의 후속 수정과 시스템 탐색·툴바 동작을 반영했으므로 초기 시안과 일부 배치가 다르다.
