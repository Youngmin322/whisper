# Whisper 유리병 자산과 불꽃 탐색 기록

[유리병과 기본 불꽃](https://www.figma.com/design/ZOEddp88P1iHaGXqZzr27U/Ember-%E2%80%94-App-UI?node-id=1305-8174) · [감정별 불꽃 전체](https://www.figma.com/design/ZOEddp88P1iHaGXqZzr27U/Ember-%E2%80%94-App-UI?node-id=1310-8174)

유리병의 벡터 원본은 이 폴더에 있고, 같은 SVG가 `Whisper/Assets.xcassets`에 별도 이름으로 등록되어 있다. 이 폴더의 `flame-*.svg`와 위 피그마 불꽃 보드는 **사용자가 선택하지 않은 첫 시안**이다. 해당 불꽃 SVG는 앱 자산에서 제거했다. 현재 앱 자산 `WhisperFlameOriginal`은 기존 앱 아이콘의 원본 PNG를 그대로 복사한 것이다.

## 유리병

세 파일 모두 `82 × 119` 캔버스를 공유한다.

1. `WhisperJarBack`: 유리 외곽과 반투명 내부를 가장 뒤에 둔다.
2. 불꽃: 병 내부 바닥 가까이에 배치한다. 여러 개면 마지막에 쓴 불꽃을 앞에 둔다.
3. `WhisperJarFront`: 유리 반사선과 입구 선을 불꽃 위에 둔다.
4. `WhisperJarCork`: 맨 앞에 두고 읽기 전환에서 따로 움직인다.

## 불꽃

첫 시안의 불꽃 SVG는 모두 `64 × 72` 투명 캔버스다. 아래는 시안에서 의도했던 감정 대응이며 앱 자산에는 포함하지 않는다.

| 앱 감정 | 자산 이름 | 원본 |
| --- | --- | --- |
| 평온 | `WhisperFlameCalm` | `flame-calm.svg` |
| 기쁨 | `WhisperFlameHappy` | `flame-happy.svg` |
| 뿌듯함 | `WhisperFlameProud` | `flame-proud.svg` |
| 설렘 | `WhisperFlameExcited` | `flame-excited.svg` |
| 지침 | `WhisperFlameTired` | `flame-tired.svg` |
| 불안 | `WhisperFlameAnxious` | `flame-anxious.svg` |

피그마 시안의 `속상`은 `WhisperFlameTroubled`로 별도 보관했다. 현재 앱의 감정 선택지에는 없다. 원래 불꽃의 주황 외곽, 노란 중심, 얼굴, 손발 없는 한 덩어리 형태를 기준으로 새 불꽃을 다시 디자인한다.

글 길이에 따른 크기 변화는 별도 이미지를 만들지 않고 표시 크기로 조절한다. 병 안에서도 적어도 한 표정은 읽히도록 앞쪽 불꽃의 최소 표시 크기를 유지한다.

제자리 일렁임은 불꽃의 아랫부분을 기준으로 아주 작은 기울기와 크기 변화로 시작한다. 움직임 줄이기 설정에서는 정적인 그림을 유지한다. 감정별 최종 불꽃은 아직 확정하지 않았다.
