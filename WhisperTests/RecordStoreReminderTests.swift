//
//  RecordStoreReminderTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("리마인드 저장과 상태 전환", .serialized)
struct RecordStoreReminderTests {
    @Test("AI 추천 간격으로 첫 알림과 다음 일정을 저장한다")
    func remembersCommitmentWithSuggestedTiming() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceRecordID = UUID()

        let plan = try #require(
            store.rememberCommitment(
                sourceRecordID: sourceRecordID,
                name: "매일 걷기",
                quote: "내일부터 매일 걸어야겠다",
                topics: ["건강"],
                reminderTiming: CommitmentReminderTiming(offsetsInHours: [24, 72, 168]),
                now: now
            )
        )

        #expect(plan.reminderDates == [
            now.addingTimeInterval(24 * 60 * 60),
            now.addingTimeInterval(72 * 60 * 60),
            now.addingTimeInterval(168 * 60 * 60)
        ])
        #expect(store.commitments.count == 1)
        #expect(store.commitments.first?.nextReminderAt == plan.reminderDates.first)
    }

    @Test("사용자가 정한 첫 만남을 우선하고 이후 AI 일정을 유지한다")
    func prioritizesCustomFirstReminderDate() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let customDate = now.addingTimeInterval(6 * 60 * 60)

        let plan = try #require(
            store.rememberCommitment(
                sourceRecordID: UUID(),
                name: "책 읽기",
                quote: "이번 주에는 책을 읽어야겠다",
                topics: ["독서"],
                reminderTiming: CommitmentReminderTiming(offsetsInHours: [24, 72]),
                firstReminderDate: customDate,
                now: now
            )
        )

        #expect(plan.reminderDates == [
            customDate,
            now.addingTimeInterval(24 * 60 * 60),
            now.addingTimeInterval(72 * 60 * 60)
        ])
        #expect(store.commitments.first?.nextReminderAt == customDate)
    }

    @Test("수동 재예약은 과거 시간을 거부하고 미래 시간에는 재확인 일정을 만든다")
    func validatesManualRescheduleDate() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let originalPlan = try #require(makeCommitment(in: store, now: now))

        let rejectedPlan = store.rescheduleCommitment(
            originalPlan.id,
            firstReminderDate: now.addingTimeInterval(-60),
            now: now
        )
        #expect(rejectedPlan == nil)

        let selectedDate = now.addingTimeInterval(12 * 60 * 60)
        let updatedPlan = try #require(
            store.rescheduleCommitment(
                originalPlan.id,
                firstReminderDate: selectedDate,
                now: now
            )
        )

        #expect(updatedPlan.reminderDates == [
            selectedDate,
            selectedDate.addingTimeInterval(72 * 60 * 60)
        ])
        #expect(store.commitments.first?.nextReminderAt == selectedDate)
    }

    @Test("같은 알림을 여러 번 열어도 만남 횟수는 한 번만 늘어난다")
    func countsOpenedEncounterOnlyOnce() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        let encounter = try #require(
            store.addEncounter(
                commitmentID: plan.id,
                scheduledAt: now.addingTimeInterval(24 * 60 * 60)
            )
        )

        #expect(store.markEncounterOpened(encounter.id, at: now))
        #expect(store.markEncounterOpened(encounter.id, at: now.addingTimeInterval(60)))
        #expect(store.commitments.first?.encounterCount == 1)
        #expect(store.commitments.first?.lastReadAt == now)
    }

    @Test("잠시 멈춤과 놓아주기가 결심 상태를 올바르게 바꾼다")
    func appliesPauseAndReleaseReactions() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let pausedStore = RecordStore(isStoredInMemoryOnly: true)
        let pausedPlan = try #require(makeCommitment(in: pausedStore, now: now))
        let pausedEncounter = try #require(
            pausedStore.addEncounter(commitmentID: pausedPlan.id, scheduledAt: now)
        )
        let pausedUntil = now.addingTimeInterval(14 * 24 * 60 * 60)

        #expect(
            pausedStore.react(
                to: pausedEncounter.id,
                with: .pause,
                pausedUntil: pausedUntil,
                at: now
            )
        )
        #expect(pausedStore.commitments.first?.lifecycleStatus(at: now) == .paused)
        #expect(pausedStore.pausedReminderPlan(for: pausedPlan.id)?.reminderDates == [pausedUntil])

        let releasedStore = RecordStore(isStoredInMemoryOnly: true)
        let releasedPlan = try #require(makeCommitment(in: releasedStore, now: now))
        let releasedEncounter = try #require(
            releasedStore.addEncounter(commitmentID: releasedPlan.id, scheduledAt: now)
        )

        #expect(releasedStore.react(to: releasedEncounter.id, with: .release, at: now))
        #expect(releasedStore.commitments.first?.lifecycleStatus(at: now) == .released)
        #expect(releasedStore.commitments.first?.nextReminderAt == nil)
    }

    private func makeCommitment(
        in store: RecordStore,
        now: Date
    ) -> CommitmentReminderPlan? {
        store.rememberCommitment(
            sourceRecordID: UUID(),
            name: "테스트 결심",
            quote: "이 마음을 기억해야겠다",
            topics: ["테스트"],
            reminderTiming: .fallback,
            now: now
        )
    }
}
