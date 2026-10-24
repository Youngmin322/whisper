import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("이전 버전 일기의 사진 보존", .serialized)
struct LegacyJournalSnapshotTests {
    private enum SaveFailure: Error { case unavailable }

    @Test("V6 일기를 다시 저장하지 않아도 원본 수정·삭제 후 사진과 회고를 보존한다", arguments: ["update", "delete"])
    func preservesMigratedJournal(operation: String) throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        let photo = Data(repeating: 0xA5, count: 200_000)
        let ids = try createLegacyStore(at: url, photo: photo)
        var snapshot: DiaryDocument!
        do {
            let store = RecordStore(configuration: configuration(url))
            let source = try #require(store.record(withID: ids.record))
            let journal = try #require(store.journals.first)
            snapshot = store.diaryDocument(for: journal)
            #expect(snapshot.text == "사진 앞\n사진 뒤\n\n그날의 회고")
            #expect(snapshot.photos.first?.data == photo)
            if operation == "delete" {
                #expect(store.delete(source))
            } else {
                #expect(store.update(source, title: "변경된 원본", content: "다른 글", emotion: "기쁨", photoData: Data([9])))
            }
            let frozen = store.diaryDocument(for: journal)
            #expect(frozen.text == snapshot.text)
            #expect(frozen.photos.map(\.data) == snapshot.photos.map(\.data))
            #expect(frozen.photos.map(\.offset) == snapshot.photos.map(\.offset))
            #expect(frozen.photos.map(\.sourceRecordID) == snapshot.photos.map(\.sourceRecordID))
            #expect(frozen.photos.map(\.caption) == snapshot.photos.map(\.caption))
            snapshot = frozen // Legacy fallback photos acquire a stable UUID when first persisted.
            let draft = store.prepareJournalDraft(JournalWritingDraft(day: JournalDay(date: journal.date), existing: journal, records: []), existing: journal)
            #expect(draft.body == snapshot.text)
            #expect(draft.document == snapshot)
        }
        let reopened = RecordStore(configuration: configuration(url))
        let journal = try #require(reopened.journals.first { $0.id == ids.journal })
        #expect(reopened.diaryDocument(for: journal) == snapshot)
        #expect(journal.body == "사진 앞\n사진 뒤")
        #expect(journal.reflection == "그날의 회고")
        #expect(journal.sourceRecordIDs == [ids.record])
        if operation == "delete" { #expect(reopened.records.isEmpty) }
        else { #expect(reopened.records.first?.photoData == Data([9])) }
    }

    @Test("삭제 저장 실패는 사진 스냅샷과 원본 삭제를 함께 되돌리고 재시도할 수 있다")
    func deletionFailureRollsBackSnapshot() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        let photo = Data([1, 2, 3])
        let ids = try createLegacyStore(at: url, photo: photo)
        var shouldFail = true
        do {
            let store = RecordStore(configuration: configuration(url)) { context in
                if shouldFail { throw SaveFailure.unavailable }
                try context.save()
            }
            let source = try #require(store.record(withID: ids.record))
            #expect(!store.delete(source))
            #expect(store.record(withID: ids.record)?.photoData == photo)
            #expect(store.diaryDocument(for: try #require(store.journals.first)).photos.first?.data == photo)
            let independentlyReopened = RecordStore(configuration: configuration(url))
            #expect(independentlyReopened.record(withID: ids.record)?.photoData == photo)
            shouldFail = false
            #expect(store.delete(try #require(store.record(withID: ids.record))))
        }
        let reopened = RecordStore(configuration: configuration(url))
        #expect(reopened.records.isEmpty)
        #expect(reopened.diaryDocument(for: try #require(reopened.journals.first)).photos.first?.data == photo)
    }

    private func createLegacyStore(at url: URL, photo: Data) throws -> (record: UUID, journal: UUID) {
        let schema = Schema(versionedSchema: WhisperSchemaV6.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let record = WhisperRecord(title: "예전 순간", content: "사진 앞\n사진 뒤", createdAt: .now, emotion: "평온", photoData: photo)
        let day = JournalDay(date: record.createdAt)
        let journal = DailyJournal(dayKey: day.key, date: day.date, title: "예전 일기", body: record.content,
            reflection: "그날의 회고", sourceRecordIDs: [record.id])
        container.mainContext.insert(record)
        container.mainContext.insert(journal)
        try container.mainContext.save()
        return (record.id, journal.id)
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "LegacySnapshot-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func configuration(_ url: URL) -> ModelConfiguration {
        ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self), url: url, cloudKitDatabase: .none)
    }
}
