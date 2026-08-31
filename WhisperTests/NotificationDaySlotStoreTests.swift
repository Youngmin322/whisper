//
//  NotificationDaySlotStoreTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("전역 알림 날짜 슬롯 저장", .serialized)
struct NotificationDaySlotStoreTests {
    @Test("오늘 소비된 슬롯은 미래 결심 알림을 교체해도 유지된다")
    func preservesConsumedTodaySlotWhileReplacingFutureCommitmentSlot() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(named: "걷기", in: store, now: now))
        let consumedDate = now.addingTimeInterval(-60 * 60)
        let consumedAt = now.addingTimeInterval(-30 * 60)
        let consumedRequestIdentifier = "test.commitment.consumed-today"
        let oldRequestIdentifier = "test.commitment.old-future"
        let oldDate = now.addingTimeInterval(24 * 60 * 60)

        #expect(
            store.saveNotificationSlot(
                slotDraft(
                    date: consumedDate,
                    requestIdentifier: consumedRequestIdentifier,
                    source: .commitment,
                    commitmentID: plan.id,
                    recordID: plan.sourceRecordID,
                    consumedAt: consumedAt,
                    createdAt: consumedDate
                )
            )
        )

        let oldReminder = ScheduledCommitmentReminder(
            encounterID: UUID(),
            requestIdentifier: oldRequestIdentifier,
            date: oldDate
        )
        #expect(
            store.replaceReminderSchedule(
                replacingRequestIdentifiers: [],
                remindersByCommitment: [plan.id: [oldReminder]],
                slotDrafts: [
                    slotDraft(
                        date: oldDate,
                        requestIdentifier: oldRequestIdentifier,
                        source: .commitment,
                        commitmentID: plan.id,
                        recordID: plan.sourceRecordID,
                        createdAt: now
                    )
                ],
                at: now
            )
        )

        let consumedSlotID = try #require(
            store.notificationSlot(requestIdentifier: consumedRequestIdentifier)?.id
        )
        let replacingIdentifiers = store.replaceableFutureCommitmentRequestIdentifiers(at: now)
        #expect(replacingIdentifiers == [oldRequestIdentifier])

        let newRequestIdentifier = "test.commitment.new-future"
        let newDate = now.addingTimeInterval(48 * 60 * 60)
        let newReminder = ScheduledCommitmentReminder(
            encounterID: UUID(),
            requestIdentifier: newRequestIdentifier,
            date: newDate
        )
        #expect(
            store.replaceReminderSchedule(
                replacingRequestIdentifiers: replacingIdentifiers,
                remindersByCommitment: [plan.id: [newReminder]],
                slotDrafts: [
                    slotDraft(
                        date: newDate,
                        requestIdentifier: newRequestIdentifier,
                        source: .commitment,
                        commitmentID: plan.id,
                        recordID: plan.sourceRecordID,
                        createdAt: now
                    )
                ],
                at: now
            )
        )

        let preservedSlot = try #require(
            store.notificationSlot(requestIdentifier: consumedRequestIdentifier)
        )
        #expect(preservedSlot.id == consumedSlotID)
        #expect(preservedSlot.consumedAt == consumedAt)
        #expect(preservedSlot.scheduledAt == consumedDate)
        #expect(store.notificationSlot(requestIdentifier: oldRequestIdentifier) == nil)
        #expect(store.notificationSlot(requestIdentifier: newRequestIdentifier) != nil)
        #expect(store.notificationSlots.count == 2)
    }

    @Test("알림센터에서 사라진 과거 만남은 소비된 날짜 슬롯으로 복원된다")
    func backfillsConsumedSlotForPastEncounter() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(named: "독서", in: store, now: now))
        let scheduledAt = now.addingTimeInterval(-2 * 60 * 60)
        let requestIdentifier = "test.commitment.missing-from-notification-center"

        _ = try #require(
            store.addEncounter(
                commitmentID: plan.id,
                scheduledAt: scheduledAt,
                notificationIdentifier: requestIdentifier
            )
        )
        #expect(store.notificationSlots.isEmpty)

        #expect(store.backfillNotificationDaySlots(at: now))

        let slot = try #require(
            store.notificationSlot(requestIdentifier: requestIdentifier)
        )
        #expect(slot.dayKey == WhisperNotificationDayKey.make(for: scheduledAt))
        #expect(slot.sourceStorage == WhisperNotificationSource.commitment.rawValue)
        #expect(slot.commitmentID == plan.id)
        #expect(slot.recordID == plan.sourceRecordID)
        #expect(slot.scheduledAt == scheduledAt)
        #expect(slot.consumedAt == scheduledAt)

        #expect(store.backfillNotificationDaySlots(at: now))
        #expect(store.notificationSlots.count == 1)
    }

    @Test("같은 날짜에는 Focus와 결심 슬롯을 함께 저장할 수 없다")
    func rejectsFocusAndCommitmentSlotsForSameDay() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(named: "운동", in: store, now: now))
        let focusDraft = slotDraft(
            date: now,
            requestIdentifier: "test.focus.today",
            source: .focus,
            recordID: plan.sourceRecordID,
            consumedAt: now,
            createdAt: now
        )
        let commitmentDraft = slotDraft(
            date: now.addingTimeInterval(60 * 60),
            requestIdentifier: "test.commitment.today",
            source: .commitment,
            commitmentID: plan.id,
            recordID: plan.sourceRecordID,
            createdAt: now
        )

        #expect(
            !store.replaceNotificationSlots(
                replacingRequestIdentifiers: [],
                with: [focusDraft, commitmentDraft]
            )
        )
        #expect(store.notificationSlots.isEmpty)

        #expect(store.saveNotificationSlot(focusDraft))
        #expect(!store.saveNotificationSlot(commitmentDraft))
        #expect(store.notificationSlots.count == 1)
        #expect(store.notificationSlots.first?.sourceStorage == WhisperNotificationSource.focus.rawValue)
        #expect(store.notificationSlots.first?.requestIdentifier == focusDraft.requestIdentifier)
    }

    @Test("Focus 선점 rollback은 일치하는 미소비 슬롯만 제거한다")
    func removesOnlyMatchingUnconsumedFocusReservation() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(named: "명상", in: store, now: now))
        let requestIdentifier = "test.focus.reservation"

        #expect(
            store.saveNotificationSlot(
                slotDraft(
                    date: now,
                    requestIdentifier: requestIdentifier,
                    source: .focus,
                    recordID: plan.sourceRecordID,
                    createdAt: now
                )
            )
        )
        let reservation = try #require(
            store.notificationSlot(requestIdentifier: requestIdentifier)
        )

        #expect(
            store.removeUnconsumedNotificationSlot(
                id: UUID(),
                requestIdentifier: requestIdentifier
            )
        )
        #expect(store.notificationSlot(requestIdentifier: requestIdentifier) != nil)

        #expect(
            store.removeUnconsumedNotificationSlot(
                id: reservation.id,
                requestIdentifier: requestIdentifier
            )
        )
        #expect(store.notificationSlot(requestIdentifier: requestIdentifier) == nil)

        #expect(
            store.saveNotificationSlot(
                slotDraft(
                    date: now,
                    requestIdentifier: requestIdentifier,
                    source: .focus,
                    recordID: plan.sourceRecordID,
                    consumedAt: now,
                    createdAt: now
                )
            )
        )
        let consumedSlot = try #require(
            store.notificationSlot(requestIdentifier: requestIdentifier)
        )
        #expect(
            !store.removeUnconsumedNotificationSlot(
                id: consumedSlot.id,
                requestIdentifier: requestIdentifier
            )
        )
        #expect(store.notificationSlot(requestIdentifier: requestIdentifier) != nil)
    }

    @Test("여러 결심의 슬롯과 만남은 한 번에 교체되고 실패 시 모두 유지된다")
    func atomicallyReplacesReminderScheduleForAllCommitments() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let walking = try #require(makeCommitment(named: "걷기", in: store, now: now))
        let reading = try #require(
            makeCommitment(named: "독서", in: store, now: now.addingTimeInterval(1))
        )

        let oldWalking = reminder(
            requestIdentifier: "test.walking.old",
            date: now.addingTimeInterval(24 * 60 * 60)
        )
        let oldReading = reminder(
            requestIdentifier: "test.reading.old",
            date: now.addingTimeInterval(48 * 60 * 60)
        )
        #expect(
            store.replaceReminderSchedule(
                replacingRequestIdentifiers: [],
                remindersByCommitment: [
                    walking.id: [oldWalking],
                    reading.id: [oldReading]
                ],
                slotDrafts: [
                    slotDraft(
                        date: oldWalking.date,
                        requestIdentifier: oldWalking.requestIdentifier,
                        source: .commitment,
                        commitmentID: walking.id,
                        recordID: walking.sourceRecordID,
                        createdAt: now
                    ),
                    slotDraft(
                        date: oldReading.date,
                        requestIdentifier: oldReading.requestIdentifier,
                        source: .commitment,
                        commitmentID: reading.id,
                        recordID: reading.sourceRecordID,
                        createdAt: now
                    )
                ],
                at: now
            )
        )

        let newWalking = reminder(
            requestIdentifier: "test.walking.new",
            date: now.addingTimeInterval(72 * 60 * 60)
        )
        let newReading = reminder(
            requestIdentifier: "test.reading.new",
            date: now.addingTimeInterval(96 * 60 * 60)
        )
        #expect(
            store.replaceReminderSchedule(
                replacingRequestIdentifiers: [
                    oldWalking.requestIdentifier,
                    oldReading.requestIdentifier
                ],
                remindersByCommitment: [
                    walking.id: [newWalking],
                    reading.id: [newReading]
                ],
                slotDrafts: [
                    slotDraft(
                        date: newWalking.date,
                        requestIdentifier: newWalking.requestIdentifier,
                        source: .commitment,
                        commitmentID: walking.id,
                        recordID: walking.sourceRecordID,
                        createdAt: now
                    ),
                    slotDraft(
                        date: newReading.date,
                        requestIdentifier: newReading.requestIdentifier,
                        source: .commitment,
                        commitmentID: reading.id,
                        recordID: reading.sourceRecordID,
                        createdAt: now
                    )
                ],
                at: now
            )
        )

        #expect(Set(store.notificationSlots.map(\.requestIdentifier)) == [
            newWalking.requestIdentifier,
            newReading.requestIdentifier
        ])
        #expect(Set(store.encounters.map(\.notificationIdentifier)) == [
            newWalking.requestIdentifier,
            newReading.requestIdentifier
        ])
        #expect(store.encounters(for: walking.id).map(\.id) == [newWalking.encounterID])
        #expect(store.encounters(for: reading.id).map(\.id) == [newReading.encounterID])
        #expect(store.commitments.first(where: { $0.id == walking.id })?.nextReminderAt == newWalking.date)
        #expect(store.commitments.first(where: { $0.id == reading.id })?.nextReminderAt == newReading.date)

        let rejectedWalking = reminder(
            requestIdentifier: "test.walking.rejected",
            date: now.addingTimeInterval(120 * 60 * 60)
        )
        let rejectedReading = reminder(
            requestIdentifier: "test.reading.rejected",
            date: now.addingTimeInterval(144 * 60 * 60)
        )
        #expect(
            !store.replaceReminderSchedule(
                replacingRequestIdentifiers: [
                    newWalking.requestIdentifier,
                    newReading.requestIdentifier
                ],
                remindersByCommitment: [
                    walking.id: [rejectedWalking],
                    reading.id: [rejectedReading]
                ],
                slotDrafts: [
                    slotDraft(
                        date: rejectedWalking.date,
                        requestIdentifier: rejectedWalking.requestIdentifier,
                        source: .commitment,
                        commitmentID: walking.id,
                        recordID: walking.sourceRecordID,
                        createdAt: now
                    )
                ],
                at: now
            )
        )

        #expect(Set(store.notificationSlots.map(\.requestIdentifier)) == [
            newWalking.requestIdentifier,
            newReading.requestIdentifier
        ])
        #expect(Set(store.encounters.map(\.notificationIdentifier)) == [
            newWalking.requestIdentifier,
            newReading.requestIdentifier
        ])
        #expect(store.commitments.first(where: { $0.id == walking.id })?.nextReminderAt == newWalking.date)
        #expect(store.commitments.first(where: { $0.id == reading.id })?.nextReminderAt == newReading.date)
    }

    @Test("과거 알림에 응답하기 전에는 그 결심의 미래 알림을 보호한다")
    func protectsFutureReminderWhileAwaitingPastResponse() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(named: "걷기", in: store, now: now))
        let pastReminder = reminder(
            requestIdentifier: "test.walking.past-unopened",
            date: now.addingTimeInterval(-60 * 60)
        )
        let futureReminder = reminder(
            requestIdentifier: "test.walking.future-backup",
            date: now.addingTimeInterval(24 * 60 * 60)
        )

        #expect(
            store.replaceReminderSchedule(
                replacingRequestIdentifiers: [],
                remindersByCommitment: [plan.id: [pastReminder, futureReminder]],
                slotDrafts: [
                    slotDraft(
                        date: pastReminder.date,
                        requestIdentifier: pastReminder.requestIdentifier,
                        source: .commitment,
                        commitmentID: plan.id,
                        recordID: plan.sourceRecordID,
                        consumedAt: pastReminder.date,
                        createdAt: now
                    ),
                    slotDraft(
                        date: futureReminder.date,
                        requestIdentifier: futureReminder.requestIdentifier,
                        source: .commitment,
                        commitmentID: plan.id,
                        recordID: plan.sourceRecordID,
                        createdAt: now
                    )
                ],
                at: now
            )
        )

        #expect(store.activeCommitmentIDsAwaitingResponse(at: now) == [plan.id])
        #expect(store.replaceableFutureCommitmentRequestIdentifiers(at: now).isEmpty)
    }

    @Test("사용자가 반응해 명시적으로 재계획하면 보호 중인 미래 알림도 교체한다")
    func explicitReplanCanReplaceProtectedFutureReminder() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try #require(makeCommitment(named: "독서", in: store, now: now))
        let pastReminder = reminder(
            requestIdentifier: "test.reading.past-unopened",
            date: now.addingTimeInterval(-60 * 60)
        )
        let futureReminder = reminder(
            requestIdentifier: "test.reading.future-backup",
            date: now.addingTimeInterval(24 * 60 * 60)
        )

        #expect(
            store.replaceReminderSchedule(
                replacingRequestIdentifiers: [],
                remindersByCommitment: [plan.id: [pastReminder, futureReminder]],
                slotDrafts: [
                    slotDraft(
                        date: pastReminder.date,
                        requestIdentifier: pastReminder.requestIdentifier,
                        source: .commitment,
                        commitmentID: plan.id,
                        recordID: plan.sourceRecordID,
                        consumedAt: pastReminder.date,
                        createdAt: now
                    ),
                    slotDraft(
                        date: futureReminder.date,
                        requestIdentifier: futureReminder.requestIdentifier,
                        source: .commitment,
                        commitmentID: plan.id,
                        recordID: plan.sourceRecordID,
                        createdAt: now
                    )
                ],
                at: now
            )
        )

        #expect(
            store.replaceableFutureCommitmentRequestIdentifiers(
                explicitlyReplanningCommitmentID: plan.id,
                at: now
            ) == [futureReminder.requestIdentifier]
        )
    }

    private func makeCommitment(
        named name: String,
        in store: RecordStore,
        now: Date
    ) -> CommitmentReminderPlan? {
        guard let record = store.addAndReturn(
            title: "\(name) 기록",
            content: "\(name)을 꾸준히 하자",
            createdAt: now
        ) else {
            return nil
        }
        return store.rememberCommitment(
            sourceRecordID: record.id,
            name: name,
            quote: "\(name)을 꾸준히 하자",
            topics: ["테스트"],
            reminderTiming: .fallback,
            now: now
        )
    }

    private func reminder(
        requestIdentifier: String,
        date: Date
    ) -> ScheduledCommitmentReminder {
        ScheduledCommitmentReminder(
            encounterID: UUID(),
            requestIdentifier: requestIdentifier,
            date: date
        )
    }

    private func slotDraft(
        date: Date,
        requestIdentifier: String,
        source: WhisperNotificationSource,
        commitmentID: UUID? = nil,
        recordID: UUID? = nil,
        consumedAt: Date? = nil,
        createdAt: Date
    ) -> NotificationDaySlotDraft {
        NotificationDaySlotDraft(
            dayKey: WhisperNotificationDayKey.make(for: date),
            scheduledAt: date,
            requestIdentifier: requestIdentifier,
            sourceStorage: source.rawValue,
            commitmentID: commitmentID,
            recordID: recordID,
            consumedAt: consumedAt,
            createdAt: createdAt
        )
    }
}
