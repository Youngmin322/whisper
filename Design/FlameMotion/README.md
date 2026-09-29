# 감정별 불꽃 움직임

여섯 승인 캐릭터는 각각 다른 움직임을 가진다. 기존 `reference.mp4`와 `FlameStepOuter/Inner00...15`는 이전 기쁨 불꽃의 동작 참고 자료로 보존한다. 현재 앱의 감정별 동작을 그 프레임으로 렌더링하지 않는다.

| 감정 | 홈 화면의 움직임 |
| --- | --- |
| 기쁨 | GitHub의 기존 16프레임 총총 걸음과 동일한 리듬·자세 |
| 평온 | 느린 부유와 작은 좌우 흔들림 |
| 불안 | 작고 빠른 움직임, 긴 멈칫함, 끝의 떨림 |
| 우울 | 낮고 무거운 움직임, 긴 휴식 |
| 분노 | 빠른 진행, 날카로운 기울임, 강한 박차 |
| 슬픔 | 천천히 이동하고 끝이 뒤늦게 따라옴 |

기쁨은 커밋된 `FlameStepOuter/Inner00...15`에서 추출한 자세 변화량과 기존 `FlameHopMotion`의 0.66초 리듬, 5.4pt 도약, 얼굴 회전·축소 값을 그대로 사용한다. 승인 기쁨 PNG는 몸과 얼굴 레이어로 결정적으로 분리한다. 몸에만 기준 자세를 적용하고 얼굴은 원본처럼 강체 회전·균일 축소하므로 얼굴 비율은 휘지 않는다.

나머지 감정은 `FlameMotionProfile`에서 리듬·이동 속도·도약·휴식·끝 변형을 정의한다. `FlameHopMotion`은 홈 화면 위치, 진행, 먼지와 그림자를 계산한다. `FlameBodyMotion`과 `FlameBodyWarp.metal`은 불꽃 끝과 바닥 쪽만 변형한다. 움직임 줄이기에서는 정지 상태를 표시한다.

승인 PNG는 `Design/EmotionFlames/Approved/`에서 가져온 그대로 사용한다. `FlameMotionPreview`는 Debug 앱 실행 인자 `--flame-motion-preview`로 열 수 있으며 여섯 감정의 정지 그림과 실제 움직임을 동시에 보여준다. `emotion-motion-preview.mp4`는 시뮬레이터에서 캡처한 여섯 감정의 비교 영상이다.

앱 화면으로 검증할 때는 현재 Xcode에서 열어 둔 체크아웃을 다시 빌드한다. 같은 브랜치의 다른 복사본을 수정해도 실행 중인 앱에는 자동으로 반영되지 않는다.

`reference-rig.json`, `tools/extract_reference_rig.py`, `reference-gait-comparison.*`, `app-common-gait.*`는 전체 PNG를 왜곡했던 이전 시도와 비교를 위한 과거 자료다. 현재 렌더러는 사용하지 않는다.
