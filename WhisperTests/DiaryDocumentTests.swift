import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("다이어리 글과 사진의 독립 보존", .serialized)
struct DiaryDocumentTests {
    @Test("여러 순간의 사진 위치를 UTF-16 좌표로 이어 붙인다")
    func appendsWithoutChangingWords() {
        var first = DiaryDocument.moment(text: "첫 👨‍👩‍👧 순간", photoData: Data([1]))
        let firstID = first.photos[0].id
        let second = DiaryDocument(text: "사진 앞\n사진 뒤", photos: [DiaryPhoto(offset: 4, data: Data([2]))])
        let start = first.text.utf16.count + 2
        first.append(second)
        #expect(first.text == "첫 👨‍👩‍👧 순간\n\n사진 앞\n사진 뒤")
        #expect(first.photos[0].id == firstID)
        #expect(first.photos[1].offset == start + 4)
        #expect(DiaryDocument.decode(first.encoded()) == first)
    }

    @Test("사진 스냅샷은 순서 대신 ID로 복원하고 사라진 사진을 다른 사진으로 대체하지 않는다")
    func restoresByIdentity() {
        let full = DiaryDocument(text: "사진 둘", photos: [DiaryPhoto(offset: 0, data: Data([1])), DiaryPhoto(offset: 3, data: Data([2]))])
        var reordered = full.withoutPhotoData
        reordered.photos.reverse()
        let restored = reordered.restoringPhotos(from: full)
        #expect(restored.photos.map(\.data) == [Data([2]), Data([1])])
        var removed = full
        removed.photos.removeFirst()
        #expect(full.withoutPhotoData.restoringPhotos(from: removed).photos[0].data == nil)
    }

    @Test("이전 초안 JSON은 새 문서 필드 없이도 복원한다")
    func decodesLegacyDraft() throws {
        let original = RecordDraft(content: "예전 본문", emotion: "기쁨", photoData: Data([1]))
        let data = try JSONEncoder().encode(original)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "document")
        let restored = try JSONDecoder().decode(RecordDraft.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored == original)
        #expect(restored.diaryDocument.photos.first?.offset == original.content.utf16.count)
    }

    @Test("순간 초안을 닫고 복원한 뒤 저장·수정해도 사진 위치와 데이터가 남는다")
    func restoresMomentDraftAndSavedPosition() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MomentDiary-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self),
                                              url: directory.appending(path: "default.store"), cloudKitDatabase: .none)
        var draft = RecordDraft(title: "함께 걸은 오후", emotion: "기쁨")
        draft.setDiaryDocument(DiaryDocument(text: "사진 앞 👨‍👩‍👧\n사진 뒤", photos: [
            DiaryPhoto(offset: "사진 앞 👨‍👩‍👧\n".utf16.count, data: Data([1, 2, 3]))
        ]))
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.save(draft))
        }
        let store = RecordStore(configuration: configuration)
        let restored = try #require(store.writingDraftStore.momentDraft)
        #expect(restored == draft)
        let record = try #require(store.saveMomentDraft(restored))
        #expect(store.writingDraftStore.momentDraft == nil)
        #expect(store.diaryDocument(for: record) == draft.diaryDocument)
        var edited = store.diaryDocument(for: record)
        edited.text = "덧붙인 문장\n" + edited.text
        edited.photos[0].offset += "덧붙인 문장\n".utf16.count
        #expect(store.update(record, title: record.title, content: edited.text, emotion: record.emotion,
                             photoData: record.photoData, document: edited))
        #expect(store.refreshPersistentState())
        #expect(store.diaryDocument(for: record) == edited)
    }

    @Test("일기를 고치고 원본을 삭제한 뒤에도 저장한 사진과 위치를 복원한다")
    func preservesJournalSnapshotAfterSourceDeletion() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Diary-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self),
                                              url: directory.appending(path: "default.store"), cloudKitDatabase: .none)
        var journalID: UUID!
        var photoID: UUID!
        do {
            let store = RecordStore(configuration: configuration)
            let source = try #require(store.addAndReturn(title: "산책", content: "사진 앞\n사진 뒤", emotion: "기쁨", photoData: Data([1, 2])))
            let moment = DiaryDocument(text: source.content, photos: [DiaryPhoto(offset: 4, data: source.photoData)])
            #expect(store.update(source, title: source.title, content: source.content, emotion: source.emotion,
                                 photoData: source.photoData, document: moment))
            var draft = store.prepareJournalDraft(JournalWritingDraft(day: JournalDay(date: source.createdAt), existing: nil, records: [source]), existing: nil)
            photoID = try #require(draft.document?.photos.first?.id)
            #expect(draft.document?.photos.first?.offset == 4)
            draft.document?.text += "\n내가 덧붙인 글"
            draft.body = try #require(draft.document?.text)
            journalID = try #require(store.saveJournalDraft(draft)).id
            #expect(source.content == "사진 앞\n사진 뒤")
            #expect(store.delete(source))
        }
        let reopened = RecordStore(configuration: configuration)
        let journal = try #require(reopened.journals.first { $0.id == journalID })
        let document = reopened.diaryDocument(for: journal)
        #expect(document.text == "사진 앞\n사진 뒤\n내가 덧붙인 글")
        #expect(document.photos.first?.id == photoID)
        #expect(document.photos.first?.offset == 4)
        #expect(document.photos.first?.data == Data([1, 2]))
        #expect(reopened.records.isEmpty)
    }

    @Test("V6 저장소의 글·사진·일기·회고를 그대로 V7로 연다")
    func migratesExistingStore() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "DiaryMigration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        let id = UUID()
        do {
            let schema = Schema(versionedSchema: WhisperSchemaV6.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            container.mainContext.insert(WhisperRecord(id: id, title: "예전 순간", content: "원문", photoData: Data([3])))
            container.mainContext.insert(DailyJournal(dayKey: JournalDay(date: .now).key, date: .now,
                                                     title: "예전 일기", body: "본문", reflection: "회고", sourceRecordIDs: [id]))
            try container.mainContext.save()
        }
        let store = RecordStore(configuration: ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self), url: url, cloudKitDatabase: .none))
        #expect(store.isPersistenceAvailable)
        #expect(store.records.first?.photoData == Data([3]))
        let journal = try #require(store.journals.first)
        #expect(journal.reflection == "회고")
        let draft = store.prepareJournalDraft(JournalWritingDraft(day: JournalDay(date: journal.date), existing: journal, records: []), existing: journal)
        #expect(draft.body == "본문\n\n회고")
        let saved = try #require(store.saveJournalDraft(draft))
        #expect(saved.body == "본문\n\n회고")
        #expect(saved.reflection.isEmpty)
    }
}
