import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("기록 단위 알림 데이터", .serialized)
struct RecordReminderDataTests {
    @Test("과거 기록 날짜와 실제 저장·수정 시각을 구분한다")
    func separatesEntryDateFromSaveAndEditTimes() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let savedAt = Date.now.addingTimeInterval(-60)
        let entryDate = savedAt.addingTimeInterval(-90 * 86_400)
        let record = try #require(store.addAndReturn(
            title: "여름 산책",
            content: "저녁 바람이 좋았다",
            createdAt: entryDate,
            savedAt: savedAt
        ))

        #expect(record.createdAt == entryDate)
        #expect(record.savedAt == savedAt)
        #expect(record.updatedAt == savedAt)

        #expect(store.update(
            record,
            title: record.title,
            content: "저녁 바람이 시원했다",
            emotion: nil,
            photoData: nil
        ))
        #expect(store.refreshPersistentState())
        let updatedRecord = try #require(store.record(withID: record.id))
        #expect(updatedRecord.createdAt == entryDate)
        #expect(updatedRecord.savedAt == savedAt)
        #expect(updatedRecord.updatedAt > savedAt)
    }

    @Test("결심 없는 기록도 제외와 일시 중지 상태를 저장한다")
    func storesReminderSettingsWithoutCommitment() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let record = try #require(store.addAndReturn(title: "일상", content: "친구와 산책했다"))
        let updatedAt = record.updatedAt
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let pausedUntil = now.addingTimeInterval(7 * 86_400)

        #expect(store.commitments.isEmpty)
        #expect(record.allowsReminders(at: now))
        #expect(store.updateRecordReminderSettings(
            recordID: record.id,
            isExcluded: false,
            pausedUntil: pausedUntil
        ))
        #expect(store.refreshPersistentState())
        let pausedRecord = try #require(store.record(withID: record.id))
        #expect(pausedRecord.reminderPausedUntil == pausedUntil)
        #expect(!pausedRecord.allowsReminders(at: now))
        #expect(pausedRecord.allowsReminders(at: pausedUntil))

        #expect(store.updateRecordReminderSettings(
            recordID: record.id,
            isExcluded: true,
            pausedUntil: pausedUntil
        ))
        #expect(!pausedRecord.allowsReminders(at: pausedUntil.addingTimeInterval(1)))
        #expect(store.updateRecordReminderSettings(
            recordID: record.id,
            isExcluded: false,
            pausedUntil: nil
        ))
        #expect(pausedRecord.allowsReminders(at: now))
        #expect(pausedRecord.updatedAt == updatedAt)
        #expect(store.records.count == 1)
    }

    @Test("예약 시각이 지나도 노출이나 열람으로 처리하지 않는다")
    func elapsedScheduleDoesNotImplyPresentationOrReading() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let record = try #require(store.addAndReturn(title: "일상", content: "좋아하는 노래를 들었다"))
        let scheduledAt = Date.now.addingTimeInterval(-86_400)
        let encounter = try #require(store.addRecordReminderEncounter(
            recordID: record.id,
            scheduledAt: scheduledAt,
            notificationIdentifier: "test.record.notification"
        ))
        let homeEncounter = try #require(store.addRecordReminderEncounter(recordID: record.id))

        #expect(store.refreshPersistentState())
        let encounters = store.recordReminderEncounters(for: record.id)
        #expect(encounters.count == 2)
        #expect(encounters.allSatisfy { $0.presentedAt == nil && $0.openedAt == nil })
        #expect(encounter.scheduledAt == scheduledAt)
        #expect(homeEncounter.scheduledAt == nil)
        #expect(homeEncounter.notificationIdentifier == nil)
        #expect(store.commitments.isEmpty)
        #expect(store.encounters.isEmpty)
        #expect(!record.isReminderExcluded)
    }

    @Test("홈과 알림이 같은 만남을 열어도 최초 열람과 확인 노출만 보존한다")
    func repeatedEventsPreserveFirstObservedTimes() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let record = try #require(store.addAndReturn(title: "일상", content: "비 온 뒤 맑아졌다"))
        let updatedAt = record.updatedAt
        let encounter = try #require(store.addRecordReminderEncounter(recordID: record.id))
        let openedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let presentedAt = openedAt.addingTimeInterval(-60)

        #expect(store.markRecordReminderOpened(encounter.id, at: openedAt))
        #expect(encounter.presentedAt == nil)
        #expect(store.markRecordReminderPresented(encounter.id, at: presentedAt))
        #expect(store.markRecordReminderOpened(encounter.id, at: openedAt.addingTimeInterval(60)))
        #expect(store.markRecordReminderPresented(encounter.id, at: openedAt))
        #expect(store.refreshPersistentState())

        let savedEncounter = try #require(store.recordReminderEncounters(for: record.id).first)
        #expect(savedEncounter.openedAt == openedAt)
        #expect(savedEncounter.presentedAt == presentedAt)
        #expect(store.recordReminderEncounters(for: record.id).count == 1)
        #expect(record.updatedAt == updatedAt)
        #expect(!record.isReminderExcluded)
    }

    @Test("같은 만남의 재저장은 멱등적이고 다른 기록이나 알림과 충돌하지 않는다")
    func rejectsOrphansAndConflictingIdentifiers() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let first = try #require(store.addAndReturn(title: "첫 기록", content: "산책"))
        let second = try #require(store.addAndReturn(title: "둘째 기록", content: "독서"))
        let encounterID = UUID()
        let scheduledAt = Date(timeIntervalSince1970: 1_800_000_000)
        let encounter = try #require(store.addRecordReminderEncounter(
            id: encounterID,
            recordID: first.id,
            scheduledAt: scheduledAt,
            notificationIdentifier: "test.record.unique"
        ))
        #expect(store.markRecordReminderOpened(encounter.id, at: scheduledAt))

        let retried = store.addRecordReminderEncounter(
            id: encounterID,
            recordID: first.id,
            scheduledAt: scheduledAt,
            notificationIdentifier: "test.record.unique"
        )
        #expect(retried?.openedAt == scheduledAt)
        #expect(store.addRecordReminderEncounter(
            id: encounterID,
            recordID: second.id,
            scheduledAt: scheduledAt,
            notificationIdentifier: "test.record.unique"
        ) == nil)
        #expect(store.addRecordReminderEncounter(
            recordID: second.id,
            notificationIdentifier: "test.record.unique"
        ) == nil)
        #expect(store.addRecordReminderEncounter(recordID: UUID()) == nil)
        #expect(!store.markRecordReminderOpened(UUID()))
        #expect(!store.markRecordReminderPresented(UUID()))
        #expect(store.recordReminderEncounters.count == 1)
        #expect(encounter.recordID == first.id)
    }

    @Test("기록 삭제 시 해당 기록의 만남만 함께 제거한다")
    func deletingRecordRemovesOnlyItsEncounters() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let first = try #require(store.addAndReturn(title: "삭제할 기록", content: "첫 내용"))
        let second = try #require(store.addAndReturn(title: "보존할 기록", content: "둘째 내용"))
        let firstID = first.id
        _ = try #require(store.addRecordReminderEncounter(recordID: firstID))
        let retainedEncounter = try #require(store.addRecordReminderEncounter(recordID: second.id))

        #expect(store.delete(first))
        #expect(store.refreshPersistentState())
        #expect(store.record(withID: firstID) == nil)
        #expect(store.recordReminderEncounters(for: firstID).isEmpty)
        #expect(store.recordReminderEncounters.map(\.id) == [retainedEncounter.id])
        #expect(store.records.map(\.id) == [second.id])
    }
}
