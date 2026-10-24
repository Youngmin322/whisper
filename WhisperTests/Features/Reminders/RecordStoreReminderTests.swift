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
    @Test("알림을 열지 않고 결심을 쉬거나 중단해도 원본과 상태가 남는다")
    func managesCommitmentWithoutEncounter() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date.now
        let plan = try #require(makeCommitment(in: store, now: now))
        let originalID = plan.sourceRecordID
        let pauseUntil = now.addingTimeInterval(14 * 24 * 60 * 60)

        #expect(store.pauseCommitment(plan.id, until: pauseUntil))
        #expect(store.commitments.first?.lifecycleStatus(at: now) == .paused)
        #expect(store.pausedReminderPlan(for: plan.id)?.reminderDates == [pauseUntil])
        #expect(store.record(withID: originalID) != nil)
        #expect(!store.pauseCommitment(plan.id, until: pauseUntil))

        let commitment = try #require(store.commitments.first)
        #expect(store.forgetCommitment(commitment))
        #expect(commitment.lifecycleStatus() == .released)
        #expect(commitment.nextReminderAt == nil)
        #expect(store.record(withID: originalID) != nil)
        #expect(!store.forgetCommitment(commitment))
    }

    @Test("예전 알림을 열어도 쉬거나 중단한 결심이 재활성화되지 않는다")
    func oldEncounterCannotReactivateCommitment() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date.now
        let plan = try #require(makeCommitment(in: store, now: now))
        let encounter = try #require(store.addEncounter(commitmentID: plan.id, scheduledAt: now))

        #expect(store.pauseCommitment(plan.id, until: now.addingTimeInterval(86_400)))
        #expect(store.markEncounterOpened(encounter.id, at: now))
        #expect(!store.react(to: encounter.id, with: .keep, at: now))
        #expect(store.commitments.first?.lifecycleStatus(at: now) == .paused)

        let commitment = try #require(store.commitments.first)
        #expect(store.forgetCommitment(commitment))
        #expect(!store.react(to: encounter.id, with: .keep, at: now))
        #expect(commitment.lifecycleStatus(at: now) == .released)
    }

    @Test("의미 프로필을 저장하고 다음 알림 한 건만 만든다")
    func storesSemanticProfileAndCreatesOneReminder() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceRecordID = try #require(
            store.addAndReturn(title: "발표 준비", content: "이번 주 발표를 준비하자", createdAt: now)?.id
        )
        let profile = CommitmentReminderProfile(
            timeSensitivity: .thisWeek,
            actionability: .concrete,
            effort: .heavy,
            cadence: .oneOff,
            preferredPeriod: .evening
        )

        let plan = try #require(
            store.rememberCommitment(
                sourceRecordID: sourceRecordID,
                name: "발표 준비",
                quote: "이번 주 발표를 준비하자",
                topics: ["발표"],
                reminderProfile: profile,
                now: now
            )
        )

        #expect(plan.reminderDates.count == 1)
        #expect(store.commitments.first?.reminderProfile == profile)
        #expect(store.commitments.first?.nextReminderAt == plan.reminderDates.first)
    }

    @Test("AI 추천 간격으로 첫 알림과 다음 일정을 저장한다")
    func remembersCommitmentWithSuggestedTiming() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sourceRecordID = try #require(
            store.addAndReturn(title: "테스트 기록", content: "내용", createdAt: now)?.id
        )

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
        let sourceRecordID = try #require(
            store.addAndReturn(title: "테스트 기록", content: "내용", createdAt: now)?.id
        )

        let plan = try #require(
            store.rememberCommitment(
                sourceRecordID: sourceRecordID,
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

        #expect(updatedPlan.reminderDates == [selectedDate])
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

    @Test("알림 경로의 만남 식별자로 누락된 만남 상태를 복원할 수 있다")
    func restoresEncounterUsingNotificationIdentifier() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        let encounterID = UUID()

        let encounter = try #require(
            store.addEncounter(
                id: encounterID,
                commitmentID: plan.id,
                scheduledAt: now,
                notificationIdentifier: "test.route.restore"
            )
        )

        #expect(encounter.id == encounterID)
        #expect(store.markEncounterOpened(encounterID, at: now))
        #expect(store.encounters.first(where: { $0.id == encounterID })?.openedAt == now)
    }

    @Test("알림을 읽고 아무것도 바꾸지 않으면 활성 상태로 다음 만남을 이어간다")
    func keepsCommitmentActiveWithoutCreatingKeepReaction() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        let encounter = try #require(
            store.addEncounter(
                commitmentID: plan.id,
                scheduledAt: now.addingTimeInterval(-60),
                notificationIdentifier: "test.opened.implicit-keep"
            )
        )

        #expect(store.markEncounterOpened(encounter.id, at: now))
        #expect(store.encounters.first(where: { $0.id == encounter.id })?.reaction == nil)
        #expect(store.commitments.first?.lifecycleStatus(at: now) == .active)
        #expect(store.reminderAllocationInputs(overriding: nil, at: now).map(\.plan.id) == [plan.id])
    }

    @Test("기존 계속 기억하기 응답은 그대로 읽을 수 있다")
    func preservesLegacyKeepReaction() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        let encounter = try #require(
            store.addEncounter(
                commitmentID: plan.id,
                scheduledAt: now.addingTimeInterval(-60),
                notificationIdentifier: "test.legacy.keep"
            )
        )

        #expect(store.react(to: encounter.id, with: .keep, at: now))
        #expect(store.encounters.first(where: { $0.id == encounter.id })?.reaction == .keep)
        #expect(store.commitments.first?.lifecycleStatus(at: now) == .active)
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

    @Test("놓아주기는 기록을 남기고 저장된 미래 알림 상태를 모두 지운다")
    func releaseRemovesFutureReminderStateButKeepsRecord() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        let currentReminder = ScheduledCommitmentReminder(
            encounterID: UUID(),
            requestIdentifier: "test.release.current",
            date: now.addingTimeInterval(-60)
        )
        let futureReminder = ScheduledCommitmentReminder(
            encounterID: UUID(),
            requestIdentifier: "test.release.future",
            date: now.addingTimeInterval(24 * 60 * 60)
        )

        #expect(
            store.replaceReminderSchedule(
                replacingRequestIdentifiers: [],
                remindersByCommitment: [plan.id: [currentReminder, futureReminder]],
                slotDrafts: [
                    NotificationDaySlotDraft(
                        dayKey: WhisperNotificationDayKey.make(for: currentReminder.date),
                        scheduledAt: currentReminder.date,
                        requestIdentifier: currentReminder.requestIdentifier,
                        sourceStorage: WhisperNotificationSource.commitment.rawValue,
                        commitmentID: plan.id,
                        recordID: plan.sourceRecordID,
                        consumedAt: currentReminder.date,
                        createdAt: now
                    ),
                    NotificationDaySlotDraft(
                        dayKey: WhisperNotificationDayKey.make(for: futureReminder.date),
                        scheduledAt: futureReminder.date,
                        requestIdentifier: futureReminder.requestIdentifier,
                        sourceStorage: WhisperNotificationSource.commitment.rawValue,
                        commitmentID: plan.id,
                        recordID: plan.sourceRecordID,
                        createdAt: now
                    )
                ],
                at: now
            )
        )

        #expect(store.react(to: currentReminder.encounterID, with: .release, at: now))
        #expect(store.records.count == 1)
        #expect(store.commitments.first?.lifecycleStatus(at: now) == .released)
        #expect(store.notificationSlot(requestIdentifier: futureReminder.requestIdentifier) == nil)
        #expect(!store.encounters.contains(where: {
            $0.notificationIdentifier == futureReminder.requestIdentifier
        }))
        #expect(store.encounters.first(where: {
            $0.notificationIdentifier == currentReminder.requestIdentifier
        })?.reaction == .release)
    }

    @Test("알림이 없는 활성 결심은 보존한 예정 시각으로 복구한다")
    func recoversActiveCommitmentUsingRetainedDate() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))

        let recoveryPlan = try #require(store.reminderRecoveryPlans(at: now).first)

        #expect(recoveryPlan.id == plan.id)
        #expect(recoveryPlan.reminderDates.first == plan.reminderDates.first)
    }

    @Test("예정 시각까지 잃은 활성 결심은 기본 간격으로 복구한다")
    func recoversActiveCommitmentUsingFallbackTiming() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        #expect(store.clearScheduledEncounters(commitmentID: plan.id))

        let recoveryPlan = try #require(store.reminderRecoveryPlans(at: now).first)

        #expect(recoveryPlan.reminderDates.first == now.addingTimeInterval(72 * 60 * 60))
    }

    @Test("아직 열지 않은 예약이 있으면 중복 복구하지 않는다")
    func doesNotRecoverCommitmentWithUnresolvedSchedule() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        let reminder = ScheduledCommitmentReminder(
            encounterID: UUID(),
            requestIdentifier: "test.pending.notification",
            date: now.addingTimeInterval(24 * 60 * 60)
        )
        #expect(
            store.replaceScheduledEncounters(
                commitmentID: plan.id,
                reminders: [reminder]
            )
        )

        #expect(store.reminderRecoveryPlans(at: now).isEmpty)
        #expect(store.replaceableNotificationIdentifiers(for: plan.id) == [
            reminder.requestIdentifier
        ])
    }

    @Test("재예약 실패 시 기존 알림 시각을 복원한다")
    func restoresExistingReminderDateAfterRescheduleFailure() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        let existingDate = now.addingTimeInterval(24 * 60 * 60)
        let existingReminder = ScheduledCommitmentReminder(
            encounterID: UUID(),
            requestIdentifier: "test.existing.notification",
            date: existingDate
        )
        #expect(
            store.replaceScheduledEncounters(
                commitmentID: plan.id,
                reminders: [existingReminder]
            )
        )
        #expect(
            store.rescheduleCommitment(
                plan.id,
                firstReminderDate: now.addingTimeInterval(48 * 60 * 60),
                now: now
            ) != nil
        )

        #expect(store.restoreNextReminderFromScheduledEncounters(commitmentID: plan.id))
        #expect(store.commitments.first?.nextReminderAt == existingDate)
    }

    @Test("존재하지 않는 기록에는 결심을 만들지 않는다")
    func rejectsCommitmentForMissingRecord() {
        let store = RecordStore(isStoredInMemoryOnly: true)

        #expect(
            store.rememberCommitment(
                sourceRecordID: UUID(),
                name: "고아 결심",
                quote: "삭제된 기록에서 늦게 도착한 분석",
                topics: ["테스트"],
                reminderTiming: .fallback
            ) == nil
        )
        #expect(store.commitments.isEmpty)
    }

#if DEBUG
    @Test("Debug 테스트 알림 상태를 예약 전에 정리할 수 있다")
    func removesFutureDebugReminderState() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(in: store, now: now))
        let identifier = "\(CommitmentReminderScheduler.debugRequestPrefix)test"

        _ = try #require(
            store.addEncounter(
                commitmentID: plan.id,
                scheduledAt: now.addingTimeInterval(60),
                notificationIdentifier: identifier
            )
        )

        #expect(store.futureDebugReminderRequestIdentifiers(at: now) == [identifier])
        #expect(
            store.removeFutureDebugReminderState(
                requestIdentifiers: [identifier],
                at: now
            )
        )
        #expect(store.encounters.isEmpty)
    }
#endif

    private func makeCommitment(
        in store: RecordStore,
        now: Date
    ) -> CommitmentReminderPlan? {
        guard let record = store.addAndReturn(
            title: "테스트 기록",
            content: "테스트 내용",
            createdAt: now
        ) else {
            return nil
        }
        return store.rememberCommitment(
            sourceRecordID: record.id,
            name: "테스트 결심",
            quote: "이 마음을 기억해야겠다",
            topics: ["테스트"],
            reminderTiming: .fallback,
            now: now
        )
    }
}
