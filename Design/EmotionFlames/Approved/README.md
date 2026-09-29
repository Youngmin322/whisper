# 승인된 감정 불꽃

| 감정 | 승인본 | 출처 | 상태 |
| --- | --- | --- | --- |
| 기쁨 | `joy.png` | 사용자 제공 `../joy-original.png` | 원본 사용 |
| 불안 | `anxiety.png` | `../Review/anxiety-01.png` | 사용자 승인 완료 |
| 우울 | `depression.png` | `../Review/depression-01.png` | 사용자 승인 완료 |
| 분노 | `anger.png` | `../Review/anger-01.png` | 사용자 승인 완료 |
| 슬픔 | `sadness.png` | `../Review/sadness-01.png` | 사용자 승인 완료 |
| 평온 | `calm.png` | `../Review/calm-01.png` | 사용자 승인 완료 |

승인한 이미지의 픽셀과 크기를 그대로 보존했다. 기쁨은 사용자 제공 PNG, 나머지 다섯 감정은 Codex 내장 image_gen으로 만든 투명 PNG다. 앱의 `Assets.xcassets`에 `EmotionFlameJoy`, `EmotionFlameAnxiety`, `EmotionFlameDepression`, `EmotionFlameAnger`, `EmotionFlameSadness`, `EmotionFlameCalm` 이름으로 등록했다. 추가 감정은 별도로 확인받은 뒤 추가한다. 생성 프롬프트는 `Prompts/`에 보관한다.
