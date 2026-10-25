# Whisper 구조도

[Archify](https://github.com/tt-a1i/archify)로 실제 코드를 읽고 만든 구조도입니다. 기준 커밋은 [`5223550`](https://github.com/Youngmin322/whisper/commit/522355051c08d96dfa2455ca7b7a1d0466894a74)입니다. 각 JSON의 `sources`에 파일과 줄 범위를 보관합니다.

| 그림 | 정적 이미지 | 상호작용 HTML | 편집 원본 |
| --- | --- | --- | --- |
| 기록과 일기 구조 | [PNG](overview.png) · [SVG](overview.svg) | [HTML](overview.html) | [JSON](overview.architecture.json) |
| 새 순간의 초안 저장과 확정 | [PNG](moment-save.png) · [SVG](moment-save.svg) | [HTML](moment-save.html) | [JSON](moment-save.workflow.json) |

GitHub에서는 PNG를 바로 볼 수 있습니다. HTML은 내려받아 브라우저에서 열면 노드 상세와 코드 근거를 탐색할 수 있습니다. GitHub Pages로 배포하면 링크로 열 수 있으며, 이 작업에서는 배포하지 않았습니다.

## 읽는 범위

전체 구조도는 화면 → 작성 → 초안 보관 → 기록 확정 → 보관함 조회의 관계를 요약합니다. iPad 화면에도 같은 `RecordStore`를 전달합니다. 현지화, 디자인 시스템, 배포 자동화의 상세와 현재 기능 플래그가 꺼진 결심 알림은 생략했습니다.

저장 흐름도는 **새 순간**을 기준으로 합니다. 최종 저장 전에 초안을 먼저 저장하고, 이후 기록 삽입·사진 문서 반영·초안 삭제를 같은 문맥에서 함께 저장합니다. 최종 저장 실패 시 rollback으로 선저장한 초안을 유지합니다. 초안 저장 자체가 실패한 경우에는 메모리에 남은 내용과 영구 저장된 내용을 구분해야 합니다. 기존 순간 수정·삭제 복구·하루 일기의 개별 분기는 이 그림의 범위 밖입니다.

핵심 근거:

- 앱 진입·공유 저장소: [ContentView](../../Whisper/App/ContentView.swift), [RecordStore 초기화](../../Whisper/Data/RecordStore.swift)
- 순간 작성·저장 요청: [QuickRecordView](../../Whisper/Features/Moments/QuickRecordView.swift), [HomeView](../../Whisper/Features/Home/HomeView.swift)
- 초안 저장·정리·rollback: [WritingDraftStore](../../Whisper/Data/WritingDraftStore.swift)
- 일기 편집·확정: [JournalEditorView](../../Whisper/Features/Journal/JournalViews.swift)
- 저장 모델·사진 문서: [WhisperSchema](../../Whisper/Data/WhisperSchema.swift)

## 검증 상태

- 두 그림 모두 Archify의 showcase 구조 검증, 파일 생성, 정적 HTML/SVG 검사를 통과했습니다.
- Archify의 **Chrome 자동 브라우저 검증은 완료하지 못했습니다.** DevTools 파이프가 응답 전에 끊어지는 실행 환경 오류가 발생했습니다. 전체 `finalize` 상태는 실패이며, 성공한 것으로 표시하지 않습니다.
- 아래 최신 보고서는 현재 HTML과 연결됩니다. 상위 폴더의 최초 보고서는 이전 범례 버전의 기록이므로 현재 결과의 근거로 사용하지 않습니다.
  - [전체 구조 보고서](review-2/overview/overview.finalize-summary.json)
  - [저장 흐름 보고서](review-2/moment-save/moment-save.finalize-summary.json)
- PNG는 생성 HTML의 SVG를 정적으로 추출하여 렌더링했고, 글자·연결선·잘림 여부를 직접 확인했습니다. 이 확인은 HTML의 브라우저 상호작용 검증을 대신하지 않습니다.

## 수정·재생성

Archify는 개인 Codex 스킬 폴더에 설치했습니다. 다음 턴부터 사용할 수 있으며, 보이지 않으면 Codex를 재시작합니다. 예를 들어 “Archify로 Whisper 구조도를 현재 코드에 맞게 갱신해줘”라고 요청할 수 있습니다.

프로젝트 루트에서 원본 JSON을 수정한 뒤 실행합니다. 이후 새 버전을 검증할 때는 기존 보고서를 덮어쓰지 않도록 새로운 `--out-dir` 경로를 사용합니다.

```sh
node "$HOME/.codex/skills/archify/bin/archify.mjs" finalize architecture \
  Docs/architecture/overview.architecture.json Docs/architecture/overview.html \
  --repo-root . --quality showcase --out-dir Docs/architecture/review-3/overview --json

node "$HOME/.codex/skills/archify/bin/archify.mjs" finalize workflow \
  Docs/architecture/moment-save.workflow.json Docs/architecture/moment-save.html \
  --repo-root . --quality showcase --out-dir Docs/architecture/review-3/moment-save --json
```

PNG·SVG 재생성은 `export-static.mjs`로 수행합니다. Node에서 `sharp`를 찾을 수 있어야 하며, 별도 위치에 설치했다면 `WHISPER_SHARP_MODULE`에 해당 모듈 경로를 지정합니다. 브라우저나 HTML 스크립트는 실행하지 않습니다. 이 경로는 기본 밝은 테마·시스템 글꼴을 사용하므로 HTML 뷰어의 이미지 내보내기와 글꼴·장식이 다를 수 있습니다.

```sh
node Docs/architecture/export-static.mjs
```

이번 설치는 설치 도우미의 DNS 연결 실패 후 GitHub 커넥터로 공식 파일을 가져오는 방식으로 진행했습니다. 실행 코드·스키마·참조·원본 예제를 포함한 188개 파일의 Git blob SHA를 검증했으며, 미리 렌더링된 예제 HTML 15개는 제외했습니다. 공식 패키지 트리는 `25cf37080fc8b1dbe758a4efc3935b55f3327083`입니다. 이는 Whisper의 기준 커밋과 별개입니다.
