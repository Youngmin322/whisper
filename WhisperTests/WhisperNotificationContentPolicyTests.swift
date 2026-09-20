//
//  WhisperNotificationContentPolicyTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@Suite("알림 미리보기 개인정보 정책")
struct WhisperNotificationContentPolicyTests {
    @MainActor
    @Test("결심 알림 진입 정보를 상세 화면까지 함께 전달한다")
    func preservesCommitmentNotificationRoute() {
        let recordID = UUID()
        let commitmentID = UUID()
        let encounterID = UUID()
        let requestIdentifier = "test.route.\(encounterID.uuidString)"

        WhisperNotificationRoute.store(
            recordID,
            commitmentID: commitmentID,
            encounterID: encounterID,
            requestIdentifier: requestIdentifier,
            postsSelectionNotification: false
        )

        #expect(WhisperNotificationRoute.consumePendingRecordID() == recordID)
        #expect(WhisperNotificationRoute.consumePendingCommitmentID() == commitmentID)
        #expect(WhisperNotificationRoute.consumePendingEncounterID() == encounterID)
        #expect(
            WhisperNotificationRoute.consumePendingRequestIdentifier() == requestIdentifier
        )
    }

    @Test("미리보기를 끄면 결심 내용 없이 다시 찾아온 마음을 알린다")
    func hidesCommitmentReminderPreview() {
        let body = WhisperNotificationContentPolicy.commitmentReminderBody(
            quote: "노출되면 안 되는 결심",
            showPreview: false
        )

        #expect(body == "기억해 둔 마음이 다시 찾아왔어요.")
        #expect(!body.contains("노출되면 안 되는"))
    }

    @Test("미리보기를 켜면 결심과 함께 다시 찾아온 마음을 알린다")
    func showsCommitmentReminderPreview() {
        let body = WhisperNotificationContentPolicy.commitmentReminderBody(
            quote: "매일 조금씩 걷자",
            showPreview: true
        )

        #expect(body == "“매일 조금씩 걷자” 그날의 마음이 다시 찾아왔어요.")
    }

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
