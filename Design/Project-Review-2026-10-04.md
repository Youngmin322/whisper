**Whisper 프로젝트 개선 검토 · 2026-10-04**

이 문서는 수정 전 검토 기록입니다. 배포 전 이슈 #31·#32·#33·#34·#36의 수정 및 검증 결과는 [배포 준비 기록](Release-Readiness-2026-10-04.md)에 정리했습니다.

검토 기준은 현재 작업 트리의 앱·테스트·설계 문서와 로컬 의존 패키지 `WhisperCore`입니다. 기준 커밋은 `eb3b537`입니다. 앱 코드는 변경하지 않았습니다.

현재 앱의 중심 경험은 잘 연결되어 있습니다. 감정을 고르고 짧은 순간을 남긴 뒤, 하루의 순간을 일기로 정리하고 보관함에서 다시 읽는 구조입니다. 따뜻한 종이색, 손글씨 제목, 감정 불꽃, 글 사이에 붙인 사진은 일관된 인상을 줍니다. 개선의 중심은 **편집 내용 보호, 검색 결과에서 실제 기억에 도달하기, 읽기 편의성, 유지보수 가능한 책임 분리**로 잡는 것이 좋겠습니다.

확인한 문제, 특정 데이터에서만 생기는 문제, 사용성 검증이 필요한 제안을 구분했습니다. 현재 꺼져 있는 결심 알림을 활성 기능으로 간주하지 않았습니다.

**1. 검토와 검증 범위**

- Xcode 27.0 / iPhone 18 Pro / iOS 27.0 시뮬레이터에서 기존 `Whisper` 테스트를 실행했습니다. **140개 테스트, 25개 suite가 통과**했습니다.
- 기존 테스트에는 저장 실패·초안 복원·마이그레이션뿐 아니라 UIHostingController를 이용한 편집기·사진·큰 글씨·키보드 검증도 있습니다. UI 검증이 없는 프로젝트가 아닙니다.
- 저장소에 있는 2026-10-03 다이어리 화면 캡처를 확인했습니다. 모든 화면을 이번 검토에서 직접 조작한 것은 아닙니다. 오래된 홈 캡처를 현재 UI로 판단하지 않았습니다.
- 형제 패키지가 없는 임시 프로젝트 복사본에서 의존성 해석 실패를 재현했습니다. 실제 GitHub Actions 실행 로그를 확인한 것은 아닙니다.
- 원본 프로젝트 밖의 임시 복사본에서 추가 검증 3개도 통과했습니다. 이 중 2개는 아래 저장 실패·레거시 사진 소실이라는 **현재 동작을 재현하는 테스트**이며, 문제가 해결되었다는 뜻은 아닙니다. 나머지 1개에서는 홈에서 일기 편집기로 전환할 때 내비게이션 바가 표시됨을 확인했습니다.
- 아래의 성능 항목은 코드에서 확인되는 작업량과 측정 대상입니다. 실기기에서 느려졌다고 단정하지 않습니다.

**2. 우선 해결할 사용 흐름과 구현 문제**

| 우선순위 | 항목 | 확인 수준 | 사용자 또는 개발 영향 |
|---|---|---|---|
| 높음 | 삭제한 일기의 수정 초안을 저장할 수 없음 | 임시 복사본에서 재현 | 다시 시도해도 저장되지 않고 복구 선택지가 없음 |
| 높음 | 형제 폴더에 의존하는 빌드 구성 | 의존성 해석 실패 재현 | 새로운 개발 환경과 현재 CI 구성에서 빌드 준비가 불완전함 |
| 높음·조건부 | 이전 일기 사진이 원본 삭제에 영향받음 | 스냅샷 없는 데이터로 재현 | 이전 버전 일기에서 보이던 사진이 사라질 수 있음 |
| 중간 | 기존 순간 수정에 임시 저장·이탈 보호 없음 | 코드 경로 확인 | 뒤로 가기나 종료 후 수정 내용을 복구할 수 없음 |
| 중간 | 검색 일치 문장과 표시되는 내용이 다름 | 코드와 기존 테스트로 확인 | 검색 결과를 열어도 찾던 문장이 바로 보이지 않음 |
| 중간 | 홈 주요 버튼의 글자 대비 부족 | 색상값 계산 | 작은 흰색 버튼 글자의 읽기 편의성 저하 |

**2-1. 삭제한 일기의 수정 초안에 복구 경로가 없습니다.**

`일기 수정 → 뒤로 이동하여 초안 보관 → 원본 일기 삭제 → 홈에서 수정 초안 재개 → 저장` 순서에서 문제가 발생합니다. 일기 삭제는 완성본과 문서만 삭제하고 수정 초안은 남깁니다. 재개한 초안에는 이미 삭제한 일기의 UUID가 남아 있어 저장이 계속 거절됩니다. 화면은 일시적인 오류처럼 “잠시 후 다시 시도”를 안내합니다. 초안 내용 자체는 남지만 일기로 완성할 수 없습니다.

근거: [일기 삭제](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/RecordStore.swift:195>), [없는 원본이면 저장 중단](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/RecordStore.swift:129>), [초안 재개](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/JournalViews.swift:35>), [공통 오류 안내](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/JournalViews.swift:141>).

원본 삭제 시 수정 초안의 처리 정책을 정해야 합니다. 작성한 내용을 보존하면서 “원본이 삭제되었어요. 새 일기로 저장할까요?”와 같은 복구 동작을 제공하는 방향을 권합니다. 같은 날짜에 다른 일기가 생겼다면 합치거나 별도 보관할지를 명시적으로 선택하게 해야 합니다. 초안을 조용히 삭제하는 해결은 피하는 것이 좋습니다.

저장 결과도 단순 `nil` 대신 `sourceDeleted`, `dayConflict`, `storageFailure`처럼 원인을 구분하면 재시도가 가능한 오류와 사용자의 선택이 필요한 오류를 정확히 안내할 수 있습니다.

**2-2. 로컬 형제 패키지가 없는 환경에서는 빌드가 시작되지 않습니다.**

[프로젝트 의존성](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper.xcodeproj/project.pbxproj:510>)은 `../WhisperCore`를 참조합니다. [현재 CI](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/.github/workflows/ios-ci.yml:22>)는 앱 저장소 하나를 checkout한 뒤 바로 `xcodebuild test`를 실행합니다. 패키지를 준비하는 단계가 없습니다.

형제 패키지를 제공하지 않은 임시 복사본에서 `xcodebuild -resolvePackageDependencies`를 실행하자 해당 경로가 없다는 오류로 종료했습니다. 현재 컴퓨터에서 테스트가 통과하는 것과 새 환경에서 재현 가능한 것은 별개입니다.

이 앱에서 함께 관리하는 코드라면 `Packages/WhisperDesignSystem`처럼 저장소 안에 포함하는 방법이 단순합니다. 독립 배포가 필요한 패키지라면 원격 SPM 의존성과 버전을 고정하십시오. 우선 기존 구조를 유지한다면 CI에서 두 저장소를 정확한 상대 경로로 checkout하고 README에 준비 절차를 기록해야 합니다.

**2-3. 이전 버전 일기의 사진 보존은 현재 버전과 다릅니다.**

현재 버전에서 문서를 저장한 일기는 사진 스냅샷을 가지므로 원본 순간을 삭제해도 사진을 보존합니다. 반면 V6→V7 전환은 lightweight migration이며, 과거의 모든 일기에 `DiaryPage`를 만들어 주지 않습니다. 아직 문서 스냅샷이 없는 일기는 원본 순간에서 사진을 구성합니다. 이 상태에서 원본을 삭제하면 일기의 사진도 없어집니다.

근거: [V6→V7 전환](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/WhisperSchema.swift:927>), [일기 문서 복원](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/RecordStore.swift:1538>), [원본에서 사진 복원](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/RecordStore.swift:1562>).

영향 범위는 **이전 데이터 중 아직 독립 문서로 저장하지 않은 일기**입니다. 기존의 원본 삭제 테스트는 이미 스냅샷을 저장한 경우를 검증합니다. 이전 사용자가 실제로 있는지에 따라 우선순위가 달라집니다.

추가 검증에서는 `DiaryPage`가 없는 동일한 데이터 형태와 실제 PNG를 사용하여, 원본 삭제 전에는 일기 문서에 사진이 있고 삭제 후에는 사라짐을 확인했습니다. V6 저장소를 다시 만드는 전환 전체를 추가 실행한 것은 아니며, 전환 자체는 기존 테스트가 검증합니다.

원본 삭제 직전에 연결된 과거 일기의 문서를 먼저 보존하거나, 전환 후 한 번 수행하는 보완 처리를 추가할 수 있습니다. 문서 보존에 실패하면 원본 삭제도 중단하는 동일 트랜잭션으로 처리해야 합니다.

**2-4. 기존 순간을 수정할 때만 편집 내용 보호가 빠져 있습니다.**

새 순간과 일기는 자동으로 초안을 보관합니다. 기존 순간 수정은 로컬 `@State`에만 있으며, 실제 저장 버튼을 누를 때에만 원본에 반영합니다. 수정 도중 뒤로 가거나 앱이 종료되면 복구할 초안이 없습니다. 취소 버튼이 변경을 버리는 것은 자연스럽지만, 의도하지 않은 이탈도 동일하게 처리되는 점이 문제입니다.

근거: [순간 수정 상태](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/RecordDetailView.swift:19>), [취소](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/RecordDetailView.swift:98>), [화면 이탈 처리](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/RecordDetailView.swift:192>), [명시적 저장](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/RecordDetailView.swift:612>).

`moment:edit:<id>`에 해당하는 수정 초안을 지원하는 것이 가장 일관됩니다. 더 작은 변경부터 한다면 변경 여부를 추적하여 이탈 시 보관·버리기를 선택하게 할 수 있습니다. 매 입력을 원본에 바로 덮어쓰면 취소의 의미가 바뀌므로 초안과 원본은 분리해야 합니다.

**2-5. 검색은 되지만 ‘왜 이 결과가 나왔는지’ 알기 어렵습니다.**

일기 검색은 일기 본문뿐 아니라 연결된 원본 순간의 제목·본문·감정도 검색합니다. 그러나 결과 미리보기는 항상 일기 본문이고, 선택하면 일기 첫 화면으로 이동합니다. 일기를 다듬으며 삭제한 문장을 검색하면 결과는 나오지만 그 문장은 현재 일기에서 보이지 않습니다. 하단의 접힌 원본 목록을 열고 여러 원본 중 하나를 찾아야 합니다.

예: 원본은 “강변에서 민수와 산책”, 완성 일기는 “오늘은 편안했다”인 경우 “민수” 검색 결과에 “오늘은 편안했다”만 표시됩니다.

근거: [검색 대상과 미리보기 생성](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/JournalArchiveIndex.swift:73>), [검색 결과 이동](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/JournalMemorySearchView.swift:22>), [기존 테스트에서 원본 검색을 확인](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/WhisperTests/JournalArchiveTests.swift:59>).

검색 결과 모델에 일치한 위치와 원본 ID를 포함하고, 일치 문장 주변을 미리보기로 보여주는 것을 권합니다. 원본에서 찾았다면 “담아 둔 순간에서 찾았어요”를 표시하고 해당 원본을 펼치거나 바로 열면 됩니다. 일기 단위로 결과를 묶는 정책 자체를 바꿀 필요는 없습니다.

**2-6. 홈 주요 버튼의 대비를 조정해야 합니다.**

`+ 순간 남기기`는 14pt medium 흰색 글자와 `#F4523B` 배경을 사용합니다. sRGB 상대 휘도 공식으로 계산한 대비는 **약 3.43:1**입니다. 작은 일반 텍스트에 참고할 수 있는 4.5:1 기준보다 낮습니다. 버튼 배경을 더 짙게 하거나 전경색 조합을 바꾸는 방향이 좋습니다. 전체 종이 배경이나 본문 색까지 모두 바꿀 필요는 없습니다. [W3C 대비 기준](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)

근거: [색상 정의](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/Color+Whisper.swift:9>), [홈 버튼 스타일](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/FlameHomeScreen.swift:194>).

**3. UI/UX를 더 발전시킬 방향 — 기능 오류와 구분한 제안**

| 제안 | 현재 관찰 | 작은 개선안 |
|---|---|---|
| 새로 쓰기와 이어 쓰기의 구분 | `+ 순간 남기기`도 항상 기존 단일 초안을 다시 엶 | 초안이 있으면 버튼 문구를 바꾸거나, 기존 초안을 보관한 채 새 순간을 시작할 수 있게 하기 |
| 저장 결과로 바로 이동 | 일기를 저장하면 홈 불꽃이 사라지고 완료 문구만 남음 | 완료 영역에 `오늘 일기 보기` 연결 추가 |
| 본문 읽기 편의성 | 네이티브 본문은 NotoSansKR-Thin 16pt | 손글씨 제목을 유지하고 본문 Regular 16–17pt와 비교 |
| 저장 상태의 명확성 | 초안 자동 저장과 완성본 저장의 차이가 화면에서 잘 드러나지 않음 | 작은 `임시 저장됨` 상태, 최초 사용 때 짧은 안내 |
| 불꽃과 기록의 연결 | 같은 감정의 불꽃이 여러 개면 시각적으로 식별하기 어려울 수 있음 | `오늘 순간 N개`, 정적인 목록 보기 또는 선택 시 시간·첫 문장 표시 |
| 오래된 날짜로 이동 | 보관함은 이전 달·다음 달 이동 중심 | 월/연도 선택이나 `오늘로` 이동을 기록 축적 후 검토 |
| 제안 시간의 개인화 | 하루 정리 제안이 22시로 고정됨 | 제안 끄기 또는 선호 시간 설정을 필요성 확인 후 추가 |
| 기록의 장기 보관 | 현재 설정은 기기 저장 안내 중심 | 파일 내보내기·가져오기와 선택적 앱 잠금을 후속 제품 과제로 검토 |

새로 쓰기는 [HomeView.openMoment](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/HomeView.swift:109>), 저장 뒤 홈은 [완료 상태](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/FlameHomeScreen.swift:29>), 본문 글꼴은 [DiaryTextView](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/DiaryTextView.swift:217>)에 근거합니다.

파일 내보내기는 앱이 제공하는 기능 제안입니다. 현재 기기 저장이 운영체제의 백업까지 없다는 뜻은 아닙니다. 동기화·다중 사진·더 세부적인 감정 선택 등은 먼저 사용 빈도와 필요성을 확인할 후속 기능입니다. 현재 설계가 의도한 짧고 부담 없는 기록 경험을 유지하는 것이 중요합니다.

큰 글씨 대응은 추가 검증이 필요합니다. 홈 작성 버튼은 151×44 고정 프레임, 온보딩 메시지는 높이 220, 22시 제안 시트는 높이 378에 스크롤이 없습니다. 글꼴 확대에 맞춰 버튼을 세로로 배치하거나 최소 높이와 스크롤을 사용하면 안전합니다. 실제 잘림을 재현하기 전에는 확정 오류로 보지 않았습니다. [Apple Dynamic Type 설명](https://developer.apple.com/videos/play/wwdc2024/10074/)

**4. 구조와 리팩터링 방향**

이미 `@Observable` 상태 저장소, 순수 정책·조합 함수, 사진 로더, 디자인 토큰이 있습니다. 이 구성을 바탕으로 **기능별 상태와 저장 책임을 명확히 나누는 점진적 구조**가 적절합니다.

| 대상 | 현재 구조 | 권하는 분리 | 기대 효과 |
|---|---|---|---|
| RecordStore | 1,914줄에 순간·일기·알림·초안 완료·저장소 초기화가 함께 있음 | 기록/일기 저장 경계, 알림 서비스, 저장소 생성 책임 분리 | 핵심 기록 기능의 변경 범위 감소 |
| 편집 화면 | 신규 순간·수정 순간·일기에 서로 다른 이탈 정책 | 공통 EditorSession 개념과 화면별 상태 모델 | 임시 저장·복구·취소의 일관성 |
| 저장 결과 | Bool/nil과 공통 오류 문구 | 도메인 오류 enum과 Result/throws | 삭제된 원본·날짜 충돌·저장 실패에 맞는 복구 |
| 화면 이동 | 여러 Bool, 선택 ID, 지연 Task의 조합 | Route/Sheet enum, 필요 시 작은 FlowCoordinator | 유효하지 않은 화면 상태와 중복 표시 방지 |
| 디자인 시스템 | 앱과 패키지가 같은 이름의 폰트·색상 토큰을 따로 정의 | 토큰·공통 컨트롤의 소유 위치 통일 | 수정 지점과 실제 적용값을 쉽게 파악 |
| 일기 문서 | body와 DiaryDocument.text를 함께 관리 | 도메인에서는 DiaryDocument를 기준으로 하고 저장 어댑터에서 호환 필드 동기화 | 텍스트·사진 위치의 불일치 방지 |
| 검색·달력 | View.body에서 전체 인덱스 재생성 | 데이터 변경 시 인덱스 갱신, 규모에 따라 월별 fetch | 검색 입력과 화면 갱신 작업량 감소 |
| 저장 스키마 | 모든 버전이 한 파일에 있음 | 버전별 파일로 정리하되 과거 스키마의 형태 유지 | 마이그레이션 검토 용이 |

`RecordStore`는 파사드로 잠시 유지하면서 내부 서비스를 옮기면 한 번에 모든 화면을 수정하지 않아도 됩니다. ViewModel은 비동기 작업·저장 상태·복구 정책이 복잡한 편집 화면부터 도입하면 충분합니다. 단순 표시 View까지 일괄적으로 감쌀 필요는 없습니다.

적용 가치가 있는 패턴은 다음과 같습니다.

- **Repository + 공유 Unit of Work:** 저장 구현을 분리하되, 완성 기록 저장과 초안 삭제는 같은 ModelContext와 트랜잭션에서 처리합니다. 현재의 원자적 저장은 유지해야 할 장점입니다.
- **편집 상태 머신:** `editing → saving → saved / failed`와 초안 보관 상태를 명시하여 중복 저장, 실패 후 복구, 이탈 처리를 통일합니다.
- **의존성 주입:** 이미 있는 저장 클로저 주입을 살리고, 시간·저장소·사진 처리·알림처럼 테스트 대체가 필요한 경계에 적용합니다.
- **순수 도메인 함수:** 기존 JournalDraftComposer·날짜 키·알림 정책처럼 입력과 결과가 명확한 규칙은 UI와 분리된 형태로 유지합니다.

예시 폴더는 `App / Features(Home, Moment, Journal, Archive, Settings) / Domain / Persistence / DesignSystem` 정도면 충분합니다. 우선 폴더와 책임을 정리한 뒤, 독립적인 빌드·재사용 필요가 확인되는 경계만 패키지로 나누는 편이 좋습니다.

TCA, VIPER, Clean Architecture 전체 도입을 요구할 만한 근거는 이번 검토에서 찾지 못했습니다. 특히 과거 SwiftData 스키마의 중복을 줄이려고 현재 모델과 공통화하거나 이름을 바꾸는 것은 데이터 호환성을 해칠 수 있습니다.

디자인 토큰 중복 예시는 앱의 [whisperBody](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/Font+Whisper.swift:22>)와 패키지의 [whisperBody](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/WhisperCore/Sources/WhisperDesignSystem/Font+Whisper.swift:72>)입니다. 같은 이름이 각각 Noto 계열 15pt, Pretendard 16pt를 가리킵니다.

**5. 성능과 복원력은 다음 조건에서 측정하십시오.**

일기 입력은 [매 변경마다 저장](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/JournalViews.swift:120>)합니다. [WritingDraftStore](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/WritingDraftStore.swift:52>)는 사진 바이트를 포함한 스냅샷을 다시 인코딩하고, 동기 저장 후 전체 초안을 읽습니다. `@MainActor`에서 실행되므로 사진이 많은 일기에서는 측정할 가치가 있습니다. 사진이 같으면 재할당하지 않는 처리는 이미 있지만 인코딩과 비교 비용은 남습니다.

우선 300–500ms 정도의 짧은 입력 지연 저장을 비교하고, 화면 종료·백그라운드 전환·최종 저장에서는 즉시 저장을 마치는 구조를 검토하십시오. 사진이 바뀌었을 때만 스냅샷을 인코딩하도록 변경 버전을 분리하면 좋습니다. 사진을 별도 asset ID로 관리할 경우에도 일기가 가진 보존 권한을 유지해야 원본 삭제에 안전합니다.

[검색 인덱스](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/JournalMemorySearchView.swift:9>)는 검색어 변경 때마다 전체 기록으로 생성됩니다. 기록 100·1,000·5,000개 조건에서 검색 지연과 메모리를 측정한 뒤 캐시·범위 조회를 적용하십시오. SwiftData는 조건·정렬·조회 개수 등을 지정하는 FetchDescriptor를 제공하므로 실제 필요한 범위만 읽는 방향으로 확장할 수 있습니다. [Apple FetchDescriptor 문서](https://developer.apple.com/documentation/swiftdata/fetchdescriptor)

불꽃은 30fps 갱신을 사용하지만 화면 비활성·Reduce Motion에서 정지하는 처리가 있습니다. 먼저 1·10·50개 조건에서 프레임 시간과 선택 편의성을 확인하십시오. 애니메이션을 제거해야 한다고 판단할 근거는 없습니다.

초안 복원은 전체 JSON decoding이 [하나의 do/catch](</Users/youngmin/Desktop/Apple Developer Academy/Challenge/Challenge5/Whisper/Whisper/WritingDraftStore.swift:107>)에 있습니다. 손상된 행 하나가 나머지 정상 초안의 목록 갱신을 막을 수 있습니다. 실제 손상을 발견한 것은 아니지만, 행 단위 복원·실패 항목 격리·payload 버전을 도입하면 복원력이 좋아집니다. 복원에 실패한 데이터를 조용히 지우는 처리는 피해야 합니다.

**6. 유지할 강점과 다음 검증**

유지할 부분은 명확합니다. 사용자가 선택한 감정을 임의로 바꾸지 않고, 원문에서 일기를 시작하며, 일기를 다듬어도 순간 원본을 보존합니다. 신규 순간과 일기의 초안 복구, 저장 실패 rollback, 초안 삭제와 완성본 저장의 원자성, 사진 전송 취소와 늦은 응답 무시, 백그라운드 사진 처리, 날짜·시간대 테스트가 있습니다. 손글씨 제목과 사진 배치도 작성·읽기 화면에 일관되게 적용됩니다.

후속 테스트는 개수를 늘리는 것보다 다음 빈틈을 메우는 데 집중하십시오.

| 검증 시나리오 | 완료 기준 |
|---|---|
| 수정 초안이 있는 일기 삭제 후 재개 | 작성 내용을 보존하며 유효한 새 저장/복구 경로 제공 |
| V6 일기 전환 후 재저장 없이 원본 삭제 | 제품 정책에 따라 사진 보존 또는 삭제 영향의 명확한 안내 |
| 순간 수정 중 뒤로 가기·앱 재시작 | 초안 복구 또는 명시적인 버리기 선택 |
| 일기에 없는 원본 문장 검색 | 일치 문장과 원본에 바로 도달 |
| 실제 버튼으로 작성→저장→보관함→검색 | 주요 경로를 E2E로 연결해 확인 |
| 홈·온보딩·제안 시트의 최대 글씨 | 내용과 주요 조작이 가려지지 않음 |
| VoiceOver로 불꽃 선택·사진 열기·저장 | 의미와 순서가 자연스럽고 조작 가능 |
| 지원 최소 OS·작은 화면·iPad | 지원을 선언한 환경에서 기본 흐름 완료 |

앱은 iOS 26.0을 지원하지만 테스트 타깃은 26.5부터입니다. 최소 지원 OS를 실제로 검증하거나 지원 범위를 일치시키는 것이 좋습니다. 이번 테스트는 iOS 27.0에서 통과했으며 다른 OS·실기기 결과를 대신하지 않습니다.

**7. 실행 순서**

1. **안정성:** 삭제된 일기 초안 복구, 이전 일기 사진 보존 정책, 순간 수정 중 이탈 보호, 패키지/CI 재현성을 먼저 해결합니다.
2. **사용성:** 검색 일치 문장 표시, 오늘 일기 바로가기, 새로 쓰기/이어 쓰기 문구, 버튼 대비와 본문 가독성을 개선합니다.
3. **유지보수:** 편집 세션과 저장 오류를 정리하고, RecordStore 책임·디자인 토큰을 통합합니다. 이 과정에서 기존 테스트를 회귀 검증으로 사용합니다.
4. **규모 확장:** 입력·검색·애니메이션을 실제 데이터량으로 측정하고 필요성이 확인된 최적화와 후속 기능을 추가합니다.

첫 사용성 확인은 3–5명에게 설명 없이 “두 번 기록하기 → 일기로 담기 → 다시 읽기 → 원본에만 있는 문장 검색하기”를 부탁하는 정도로 시작할 수 있습니다. 완수 여부, 멈춘 지점, 기대와 실제 동작이 달랐던 순간을 기록하면 위 제안의 우선순위를 조정하기 좋습니다.

검토 당시 로컬 검증 자료: [기존 테스트 로그](/private/tmp/whisper-project-review-tests.log), [추가 검증 소스](/private/tmp/whisper-review-probes/ReviewRegressionProbeTests.swift), [추가 검증 로그](/private/tmp/whisper-review-probe-tests.log), [패키지 해석 실패 로그](/private/tmp/whisper-review-clean-check.log). 임시 디렉터리의 파일은 이후 정리될 수 있습니다.
