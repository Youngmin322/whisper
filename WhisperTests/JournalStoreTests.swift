import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("일기와 원본 순간의 독립 보관", .serialized)
struct JournalStoreTests {
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
