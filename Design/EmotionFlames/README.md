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
