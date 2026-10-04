import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("기존 순간의 수정 초안", .serialized)
struct MomentEditDraftTests {
    private enum SaveFailure: Error { case unavailable }

    @Test("여러 순간 수정 초안을 새 순간 초안과 분리하고 앱 재시작 후 복구한다")
    func restoresIndependentEdits() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MomentEdits-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self),
            url: directory.appending(path: "default.store"), cloudKitDatabase: .none)
        let newDraft = RecordDraft(content: "새 순간도 유지", emotion: "기쁨")
        var edits: [RecordDraft] = []
        do {
            let store = RecordStore(configuration: configuration)
            for index in 1...2 {
                let original = try #require(store.addAndReturn(title: "원본 \(index)", content: "원본 본문", emotion: "평온", photoData: Data([1])))
                var edit = RecordDraft(title: "수정 \(index)", emotion: "슬픔", existingRecordID: original.id)
                edit.setDiaryDocument(DiaryDocument(text: "수정 앞\n수정 뒤", photos: [DiaryPhoto(offset: 4, data: Data([2, 3]))]))
                edits.append(edit)
                #expect(store.writingDraftStore.save(edit))
                #expect(original.content == "원본 본문")
                #expect(original.photoData == Data([1]))
            }
            #expect(store.writingDraftStore.save(newDraft))
            #expect(store.writingDraftStore.count == 3)
        }
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.momentDraft == newDraft)
            for edit in edits {
                #expect(store.writingDraftStore.momentEditDraft(for: edit.existingRecordID!) == edit)
            }
            let saved = try #require(store.saveMomentEditDraft(edits[0]))
            #expect(saved.id == edits[0].existingRecordID)
            #expect(saved.content == edits[0].content)
            #expect(saved.emotion == edits[0].emotion)
            #expect(store.diaryDocument(for: saved) == edits[0].diaryDocument)
            #expect(store.writingDraftStore.momentEditDrafts == [edits[1]])
            #expect(store.writingDraftStore.momentDraft == newDraft)
            #expect(store.saveMomentEditDraft(edits[0])?.id == saved.id)
            #expect(store.records.count == 2)
            #expect(store.writingDraftStore.discard(id: edits[1].id))
            #expect(store.record(withID: edits[1].existingRecordID!)?.content == "원본 본문")
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.writingDraftStore.momentEditDrafts.isEmpty)
        #expect(reopened.writingDraftStore.momentDraft == newDraft)
        #expect(reopened.record(withID: edits[0].existingRecordID!)?.photoData == edits[0].photoData)
    }

    @Test("최종 수정 저장 실패는 원본과 수정 초안 삭제를 함께 되돌린다")
    func failedPublishRetainsOriginalAndDraft() throws {
        var attempt = 0
        var failingAttempt: Int?
        let store = RecordStore(isStoredInMemoryOnly: true) { context in
            attempt += 1
            if attempt == failingAttempt { throw SaveFailure.unavailable }
            try context.save()
        }
        let original = try #require(store.addAndReturn(title: "원본", content: "원본 본문", photoData: Data([1])))
        let id = original.id
        let edit = RecordDraft(title: "수정 제목", content: "최신 수정 본문", emotion: "평온", photoData: Data([2]), existingRecordID: id)
        #expect(store.writingDraftStore.save(edit))
        failingAttempt = attempt + 2
        #expect(store.saveMomentEditDraft(edit) == nil)
        #expect(store.record(withID: id)?.content == "원본 본문")
        #expect(store.record(withID: id)?.photoData == Data([1]))
        #expect(store.writingDraftStore.momentEditDraft(for: id) == edit)
        failingAttempt = nil
        #expect(store.saveMomentEditDraft(edit)?.id == id)
        #expect(store.writingDraftStore.momentEditDrafts.isEmpty)
        #expect(store.records.count == 1)
    }

    @Test("임시 저장 실패 중 수정 초안의 최신 내용과 사진을 유지하고 재시도한다")
    func retriesAutosaveFailure() throws {
        var shouldFail = false
        let store = RecordStore(isStoredInMemoryOnly: true) { context in
            if shouldFail { throw SaveFailure.unavailable }
            try context.save()
        }
        let original = try #require(store.addAndReturn(title: "원본", content: "본문"))
        var edit = RecordDraft(content: "처음 수정", existingRecordID: original.id)
        #expect(store.writingDraftStore.save(edit))
        shouldFail = true
        edit.content = "실패 중 최신 수정"
        edit.photoData = Data([9])
        #expect(!store.writingDraftStore.save(edit))
        store.writingDraftStore.reload()
        #expect(store.writingDraftStore.momentEditDraft(for: original.id) == edit)
        #expect(store.writingDraftStore.errorMessage != nil)
        shouldFail = false
        store.writingDraftStore.retry()
        #expect(store.writingDraftStore.momentEditDraft(for: original.id) == edit)
        #expect(store.writingDraftStore.errorMessage == nil)
        #expect(original.content == "본문")
    }

    @Test("삭제된 순간의 수정 초안은 명시적으로 새 순간으로 복구하고 다른 초안을 보존한다")
    func recoversDeletedSource() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let original = try #require(store.addAndReturn(title: "삭제할 순간", content: "원본"))
        let edit = RecordDraft(title: "복구", content: "수정한 내용", emotion: "평온", photoData: Data([3]), existingRecordID: original.id)
        let newDraft = RecordDraft(content: "다른 새 순간")
        #expect(store.writingDraftStore.save(edit))
        #expect(store.writingDraftStore.save(newDraft))
        #expect(store.delete(original))
        #expect(store.saveMomentEditDraft(edit) == nil)
        #expect(store.saveMomentDraft(edit) == nil)
        #expect(store.writingDraftStore.momentEditDrafts == [edit])
        let recovered = try #require(store.saveMomentDraft(edit, recoveringDeletedMoment: true))
        #expect(recovered.id == edit.id)
        #expect(recovered.photoData == edit.photoData)
        #expect(recovered.content == edit.content)
        #expect(store.writingDraftStore.momentEditDrafts.isEmpty)
        #expect(store.writingDraftStore.momentDraft == newDraft)
        #expect(store.saveMomentDraft(edit, recoveringDeletedMoment: true)?.id == recovered.id)
        #expect(store.records.count == 1)
    }

    @Test("기존 새 순간 초안 JSON은 수정 대상 필드가 없어도 복원한다")
    func decodesOldDraftPayload() throws {
        let draft = RecordDraft(content: "이전 초안", emotion: "기쁨")
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])
        json.removeValue(forKey: "existingRecordID")
        let restored = try JSONDecoder().decode(RecordDraft.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored == draft)
        #expect(restored.storageKey == "moment")
    }
}
