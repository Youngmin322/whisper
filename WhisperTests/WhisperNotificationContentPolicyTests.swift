//
//  WhisperNotificationContentPolicyTests.swift
//  WhisperTests
//

import Testing
@testable import Whisper

@Suite("알림 미리보기 개인정보 정책")
struct WhisperNotificationContentPolicyTests {
    @Test("미리보기를 끄면 Focus 알림에서 기록 제목과 내용을 숨긴다")
    func hidesFocusReminderPreview() {
        let copy = WhisperNotificationContentPolicy.focusReminderCopy(
            title: "노출되면 안 되는 제목",
            content: "노출되면 안 되는 기록 내용",
            showPreview: false
        )

        #expect(copy.subtitle == nil)
        #expect(!copy.body.contains("노출되면 안 되는"))
    }

    @Test("미리보기를 켜면 Focus 알림에 기록 제목과 내용을 표시한다")
    func showsFocusReminderPreview() {
        let copy = WhisperNotificationContentPolicy.focusReminderCopy(
            title: "오늘의 결심",
            content: "작은 일부터 다시 시작해 보자.",
            showPreview: true
        )

        #expect(copy.subtitle == "오늘의 결심")
        #expect(copy.body == "작은 일부터 다시 시작해 보자.")
    }
}
