import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("순간의 여러 사진 보존", .serialized)
struct MultiPhotoAttachmentTests {
    @Test("사진을 더 붙이고 한 장씩 삭제해도 나머지 사진과 UTF-16 위치가 유지된다")
    func appendsAndRemovesIndividualPhotos() throws {
        var draft = RecordDraft(content: "앞😀뒤", emotion: "기쁨", photoData: Data([1]))
        let original = try #require(draft.diaryDocument.photos.first)
        // Offset 2 is inside the emoji surrogate pair and must move before it.
        draft.appendPhotos([Data([2]), Data([3])], at: 2)
        #expect(draft.content == "앞😀뒤")
        #expect(draft.diaryDocument.photos.map(\.data) == [Data([2]), Data([3]), Data([1])])
        #expect(draft.diaryDocument.photos.map(\.offset) == [1, 1, 4])
        #expect(draft.diaryDocument.photos.last?.id == original.id)
        let first = try #require(draft.diaryDocument.photos.first)
        draft.removePhoto(id: first.id)
        #expect(draft.photoData == Data([3]))
        #expect(draft.diaryDocument.photos.map(\.data) == [Data([3]), Data([1])])
        draft.appendPhotos([Data([4])], at: 4)
        #expect(draft.diaryDocument.photos.map(\.data) == [Data([3]), Data([1]), Data([4])])
        draft.removeAllPhotos()
        #expect(draft.photoData == nil)
        #expect(draft.diaryDocument.photos.isEmpty)
        #expect(draft.content == "앞😀뒤")
    }

    @Test("사진 여러 장의 초안·순간·수정·일기 스냅샷을 앱 재실행과 원본 삭제 후에도 복구한다")
    func persistsFullPhotoLifecycle() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MultiPhoto-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self),
            url: directory.appending(path: "default.store"), cloudKitDatabase: .none)
        var draft = RecordDraft(title: "여러 장의 순간", content: "사진 앞\n사진 뒤", emotion: "기쁨")
        draft.appendPhotos([Data([1]), Data([2]), Data([3])], at: 4)
        let snapshot = draft.diaryDocument
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.save(draft))
        }
        var edit: RecordDraft!
        var journalID: UUID!
        do {
            let store = RecordStore(configuration: configuration)
            let restored = try #require(store.writingDraftStore.momentDraft)
            #expect(restored == draft)
            let record = try #require(store.saveMomentDraft(restored))
            #expect(record.photoData == Data([1]))
            #expect(store.diaryDocument(for: record) == snapshot)
            let journalDraft = store.prepareJournalDraft(
                JournalWritingDraft(day: JournalDay(date: record.createdAt), existing: nil, records: [record]), existing: nil)
            journalID = try #require(store.saveJournalDraft(journalDraft)).id
            #expect(store.diaryDocument(for: try #require(store.journals.first)).photos.map(\.data)
                    == [Data([1]), Data([2]), Data([3])])
            edit = RecordDraft(title: record.title, content: record.content, emotion: record.emotion,
                photoData: record.photoData, document: store.diaryDocument(for: record), existingRecordID: record.id)
            edit.removePhoto(id: snapshot.photos[0].id)
            edit.appendPhotos([Data([4])], at: edit.content.utf16.count)
            #expect(store.writingDraftStore.save(edit))
        }
        do {
            let store = RecordStore(configuration: configuration)
            let restored = try #require(store.writingDraftStore.momentEditDraft(for: draft.id))
            #expect(restored == edit)
            let record = try #require(store.saveMomentEditDraft(restored))
            #expect(record.photoData == Data([2]))
            #expect(store.diaryDocument(for: record).photos.map(\.data) == [Data([2]), Data([3]), Data([4])])
            #expect(store.diaryDocument(for: record).photos.map(\.offset) == [4, 4, draft.content.utf16.count])
            // Updating only the text through the legacy API must preserve all images too.
            #expect(store.update(record, title: record.title, content: record.content + "!", emotion: record.emotion,
                photoData: record.photoData))
            #expect(store.diaryDocument(for: record).photos.map(\.data) == [Data([2]), Data([3]), Data([4])])
            #expect(store.delete(record))
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.records.isEmpty)
        #expect(reopened.writingDraftStore.count == 0)
        let journal = try #require(reopened.journals.first { $0.id == journalID })
        let frozen = reopened.diaryDocument(for: journal)
        #expect(frozen.photos.map(\.id) == snapshot.photos.map(\.id))
        #expect(frozen.photos.map(\.data) == [Data([1]), Data([2]), Data([3])])
        #expect(frozen.photos.map(\.offset) == [4, 4, 4])
    }
}
