import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("일기와 원본 순간의 독립 보관", .serialized)
struct JournalStoreTests {
    @Test("일기에 담은 순간은 홈에서 제외하고 원본은 보관하며 다시 불러와도 유지한다")
    func collectedMomentsLeaveHome() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let day = Calendar.current.startOfDay(for: .now)
        let first = try #require(store.addAndReturn(
            title: "첫 순간", content: "병에 담을 원문", createdAt: day.addingTimeInterval(3600)
        ))
        let second = try #require(store.addAndReturn(
            title: "둘째 순간", content: "다음 원문", createdAt: day.addingTimeInterval(7200)
        ))
        _ = store.addAndReturn(title: "어제", content: "어제 원문", createdAt: day.addingTimeInterval(-3600))

        #expect(store.uncollectedMoments(on: day).map(\.id) == [first.id, second.id])
        let draft = JournalDraftComposer.compose(on: day, records: store.records, existing: nil)
        // 초안만 열고 저장하지 않은 순간은 홈에 남는다.
        #expect(store.uncollectedMoments(on: day).count == 2)
        _ = try #require(store.saveJournal(
            on: day, title: draft.title, body: draft.body, sourceRecordIDs: draft.sourceRecordIDs
        ))

        #expect(store.uncollectedMoments(on: day).isEmpty)
        #expect(store.record(withID: first.id)?.content == "병에 담을 원문")
        #expect(store.record(withID: second.id)?.content == "다음 원문")
        #expect(store.refreshPersistentState())
        #expect(store.uncollectedMoments(on: day).isEmpty)
    }

    @Test("병에 담은 뒤 추가한 순간만 홈에 나타나며 다시 담으면 중복 없이 제외한다")
    func newMomentsRemainUntilCollected() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let day = Calendar.current.startOfDay(for: .now)
        let first = try #require(store.addAndReturn(
            title: "먼저", content: "먼저 담은 순간", createdAt: day.addingTimeInterval(3600)
        ))
        let journal = try #require(store.saveJournal(
            on: day, title: "오늘", body: first.content, sourceRecordIDs: [first.id]
        ))
        let second = try #require(store.addAndReturn(
            title: "나중", content: "새로운 순간", createdAt: day.addingTimeInterval(7200)
        ))
        #expect(store.uncollectedMoments(on: day).map(\.id) == [second.id])

        let draft = JournalDraftComposer.compose(on: day, records: store.records, existing: journal)
        #expect(draft.body == "먼저 담은 순간\n\n새로운 순간")
        let updated = try #require(store.saveJournal(
            on: day, title: draft.title, body: draft.body, sourceRecordIDs: draft.sourceRecordIDs
        ))
        #expect(updated.id == journal.id)
        #expect(updated.sourceRecordIDs == [first.id, second.id])
        #expect(store.uncollectedMoments(on: day).isEmpty)
    }

    @Test("원본 순간 삭제 뒤 일기 복사 본문과 출처 표시는 남고 일기 삭제 뒤 원본은 남는다")
    func journalAndMomentDeleteIndependently() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let date = Date.now
        let photo = Data([0x01, 0x02])
        let first = try #require(store.addAndReturn(
            title: "첫 순간", content: "복사할 문장", createdAt: date,
            emotion: "기쁨", photoData: photo
        ))
        let second = try #require(store.addAndReturn(
            title: "둘째 순간", content: "남겨둘 원문", createdAt: date
        ))
        let journal = try #require(store.saveJournal(
            on: date, title: "오늘", body: "복사할 문장", sourceRecordIDs: [first.id, second.id]
        ))
        let journalID = journal.id
        let firstID = first.id
        let secondID = second.id

        #expect(store.delete(first))
        let afterSourceDelete = try #require(store.journals.first { $0.id == journalID })
        #expect(afterSourceDelete.body == "복사할 문장")
        #expect(afterSourceDelete.sourceRecordIDs == [firstID, secondID])
        #expect(store.record(withID: firstID) == nil)
        #expect(store.record(withID: secondID)?.content == "남겨둘 원문")

        #expect(store.deleteJournal(afterSourceDelete))
        #expect(store.journals.isEmpty)
        #expect(store.record(withID: secondID)?.content == "남겨둘 원문")
        #expect(store.uncollectedMoments(on: date).map(\.id) == [secondID])
    }

    @Test("일기 수정은 기존 감정 회고와 UUID를 보존한다")
    func updatePreservesLegacyJournalFields() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let date = Date.now
        let journal = try #require(store.saveJournal(
            on: date, title: "원래 제목", body: "원래 본문", sourceRecordIDs: []
        ))
        let originalID = journal.id
        journal.reflection = "기존 회고"
        journal.emotion = "평온"

        let updated = try #require(store.saveJournal(
            on: date, title: "새 제목", body: "새 본문", sourceRecordIDs: []
        ))
        #expect(updated.id == originalID)
        #expect(updated.reflection == "기존 회고")
        #expect(updated.emotion == "평온")
        #expect(updated.body == "새 본문")
    }
}
