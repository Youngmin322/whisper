# 마음의 불꽃들 — 확정 세트

기쁨은 사용자가 제공한 대표 캐릭터 원본이다. 불안·우울·분노·슬픔·평온은 Codex 내장 image_gen으로 만들고 한 캐릭터씩 사용자 승인을 받았다. 확정본은 `Approved/`에 저장했다.

| 감정 | 특징 | 확정 파일 |
| --- | --- | --- |
| 기쁨 | 따뜻한 주황과 큰 웃음 | `Approved/joy.png` |
| 불안 | 보랏빛 몸체, 휘어진 끝과 걱정스러운 표정 | `Approved/anxiety.png` |
| 우울 | 푸른 몸체, 처진 끝과 무거운 눈꺼풀 | `Approved/depression.png` |
| 분노 | 산호색 몸체, 치솟은 불꽃과 다문 입 | `Approved/anger.png` |
| 슬픔 | 청록색 몸체, 처진 끝과 눈물 한 방울 | `Approved/sadness.png` |
| 평온 | 연두색 몸체, 감은 눈과 작은 미소 | `Approved/calm.png` |

## 파일 사용

- 개별 파일은 승인된 이미지의 픽셀·크기·투명 배경을 그대로 보존한 PNG다.
- `character-sheet.png`와 `index.html`은 확정된 여섯 캐릭터의 비교 화면이다.
- 상위 폴더의 `EmotionFlames.zip`에는 확정 PNG, 비교 시트, 프롬프트를 담았다.
- 생성 프롬프트는 `Approved/Prompts/`에 있다.
- 앱의 `Whisper/Assets.xcassets`에 개별 이미지 에셋 6개를 등록했다. 아래 이름으로 SwiftUI `Image`에서 사용할 수 있다.
- `FlameCharacter`와 홈의 움직이는 불꽃은 승인된 PNG를 사용한다. 기존 불꽃 SVG 12개의 원형 배경 레이어를 제거했다.
- 홈 모션은 `FlameAppearance`의 외형과 `FlameMotionProfile`의 감정별 움직임을 분리한다. 같은 이름의 PNG 교체 시 새 몸의 크기와 여백을 자동으로 읽어 연결한다. 불꽃 끝과 바닥만 국소 변형하고 얼굴이 있는 중앙은 보존한다. 감정별 리듬과 확인 방법은 `../FlameMotion/README.md`에 있다.
- 순간 기록과 감정 수정에서 기쁨·평온·불안·우울·분노·슬픔 6종을 선택할 수 있다. 기록 상세, 대표 감정, 홈, 보관함의 병도 같은 PNG를 사용한다.
- 이전 기록의 감정 이름은 보존하고 뿌듯함·설렘은 기쁨, 지침은 우울, 속상은 슬픔, 차분함은 평온 캐릭터로 표시한다.
- `app-emotion-picker.png`는 실제 `QuickRecordView`를 iOS 시뮬레이터에서 렌더링한 적용 확인 화면이다.

| 감정 | 앱 에셋 이름 |
| --- | --- |
| 기쁨 | `EmotionFlameJoy` |
| 불안 | `EmotionFlameAnxiety` |
| 우울 | `EmotionFlameDepression` |
| 분노 | `EmotionFlameAnger` |
| 슬픔 | `EmotionFlameSadness` |
| 평온 | `EmotionFlameCalm` |

```swift
Image("EmotionFlameAnxiety")
    .resizable()
    .scaledToFit()
```

`render.cjs`는 `Approved/` 원본만 읽어 비교 시트를 만들며 개별 이미지를 다시 그리거나 변경하지 않는다. 초기 미승인 벡터 시안과 기존 ZIP은 `Explorations/`에 보관했다. `generate.py`는 초기 벡터 탐색을 위한 코드이며 확정 세트에는 사용하지 않는다.
