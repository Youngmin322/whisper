import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("삭제된 일기 초안의 안전한 복구", .serialized)
struct JournalDraftRecoveryTests {
    private enum SaveFailure: Error { case unavailable }

    @Test("앱을 다시 열어 원본이 삭제된 초안의 글·사진·감정을 새 일기로 복구한다")
    func recoversAfterReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "JournalRecovery-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self),
            url: directory.appending(path: "default.store"), cloudKitDatabase: .none)
        let day = JournalDay(date: .now)
        var snapshot: JournalWritingDraft!
        do {
            let store = RecordStore(configuration: configuration)
            let original = try #require(store.saveJournal(on: day, title: "원본", body: "원본 글", sourceRecordIDs: []))
            var draft = JournalWritingDraft(day: day, existing: original, records: [])
            draft.title = "복구할 제목"
            draft.body = "사진 앞\n사진 뒤"
            draft.representativeEmotion = "평온"
            draft.document = DiaryDocument(text: draft.body, photos: [DiaryPhoto(offset: 4, data: Data([1, 2, 3]))])
            snapshot = draft
            #expect(store.writingDraftStore.save(draft))
            #expect(store.deleteJournal(original))
        }
        do {
            let store = RecordStore(configuration: configuration)
            let restored = try #require(store.writingDraftStore.journalDrafts.first)
            #expect(restored == snapshot)
            #expect(store.saveJournalDraft(restored) == nil)
            #expect(store.journalDraftSaveFailure == .sourceDeleted)
            #expect(store.writingDraftStore.journalDrafts == [restored])
            let saved = try #require(store.saveJournalDraft(restored, recoveringDeletedJournalOn: day))
            #expect(saved.id == restored.id)
            #expect(saved.title == restored.title)
            #expect(saved.body == restored.body)
            #expect(saved.emotion == restored.representativeEmotion)
            #expect(store.diaryDocument(for: saved) == restored.document)
            #expect(store.writingDraftStore.count == 0)
            #expect(store.saveJournalDraft(restored, recoveringDeletedJournalOn: day)?.id == saved.id)
            #expect(store.journals.count == 1)
        }
        let reopened = RecordStore(configuration: configuration)
        let saved = try #require(reopened.journals.first)
        #expect(reopened.diaryDocument(for: saved) == snapshot.document)
        #expect(reopened.writingDraftStore.count == 0)
    }

    @Test("같은 날짜의 다른 일기는 보존하고 빈 날짜에 복구한다")
    func preservesConflictingJournal() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let day = JournalDay(date: .now)
        let original = try #require(store.saveJournal(on: day, title: "삭제할 일기", body: "원본", sourceRecordIDs: []))
        var draft = JournalWritingDraft(day: day, existing: original, records: [])
        draft.body = "초안 내용"
        #expect(store.writingDraftStore.save(draft))
        #expect(store.deleteJournal(original))
        let replacement = try #require(store.saveJournal(on: day, title: "보존할 일기", body: "다른 일기", sourceRecordIDs: []))
        #expect(store.saveJournalDraft(draft, recoveringDeletedJournalOn: day) == nil)
        #expect(store.journalDraftSaveFailure == .dayConflict)
        #expect(store.journals.count == 1)
        #expect(replacement.body == "다른 일기")
        #expect(store.writingDraftStore.journalDrafts == [draft])
        let nextDay = JournalDay(date: day.nextBoundary, calendar: day.calendar)
        let saved = try #require(store.saveJournalDraft(draft, recoveringDeletedJournalOn: nextDay))
        #expect(saved.dayKey == nextDay.key)
        #expect(saved.body == draft.body)
        #expect(store.journals.count == 2)
        #expect(store.journal(on: day)?.id == replacement.id)
        #expect(store.writingDraftStore.count == 0)
    }

    @Test("복구의 최종 저장이 실패하면 초안 삭제와 새 일기 생성을 함께 되돌린다")
    func recoveryFailureIsAtomic() throws {
        var attempt = 0
        var failingAttempt: Int?
        let store = RecordStore(isStoredInMemoryOnly: true) { context in
            attempt += 1
            if attempt == failingAttempt { throw SaveFailure.unavailable }
            try context.save()
        }
        let day = JournalDay(date: .now)
        let original = try #require(store.saveJournal(on: day, title: "원본", body: "원본", sourceRecordIDs: []))
        var draft = JournalWritingDraft(day: day, existing: original, records: [])
        draft.body = "잃으면 안 되는 수정"
        draft.document = DiaryDocument.moment(text: draft.body, photoData: Data([7, 8]))
        #expect(store.writingDraftStore.save(draft))
        #expect(store.deleteJournal(original))
        failingAttempt = attempt + 2 // Draft flush succeeds; publishing fails.
        #expect(store.saveJournalDraft(draft, recoveringDeletedJournalOn: day) == nil)
        #expect(store.journalDraftSaveFailure == .storageFailure)
        #expect(store.journals.isEmpty)
        #expect(store.writingDraftStore.journalDrafts == [draft])
        failingAttempt = nil
        #expect(store.saveJournalDraft(draft, recoveringDeletedJournalOn: day)?.id == draft.id)
        #expect(store.writingDraftStore.count == 0)
    }
}
