import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("새 순간과 여러 초안의 보존", .serialized)
struct NewMomentDraftTests {
    private enum SaveFailure: Error { case unavailable }

    @Test("여러 순간 초안을 보관하고 다시 열어 수정해도 각 글·사진·감정을 유지한다")
    func restoresIndependentMoments() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        var first = photoDraft(title: "어제 쓰던 글", text: "사진 앞\n사진 뒤", emotion: "평온", bytes: [1, 2])
        let second = photoDraft(title: "새로 쓰는 글", text: "새 글 앞\n새 글 뒤", emotion: "기쁨", bytes: [3, 4])
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.save(first))
            #expect(store.writingDraftStore.save(second))
            #expect(store.writingDraftStore.save(RecordDraft()))
            #expect(store.writingDraftStore.count == 2)
            #expect(store.records.isEmpty)
        }
        do {
            let reopened = RecordStore(configuration: configuration)
            #expect(reopened.writingDraftStore.momentDrafts == [second, first])
            first.title = "이어서 수정한 제목"
            first.emotion = "설렘"
            first.setDiaryDocument(DiaryDocument(text: "이어 쓴 앞\n이어 쓴 뒤",
                photos: [DiaryPhoto(offset: 6, data: Data([5, 6]))]))
            #expect(reopened.writingDraftStore.save(first))
            #expect(reopened.writingDraftStore.count == 2)
            #expect(reopened.writingDraftStore.momentDrafts.first { $0.id == second.id } == second)
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.writingDraftStore.momentDrafts == [first, second])
        #expect(reopened.writingDraftStore.count == 2)
        #expect(reopened.records.isEmpty)
    }

    @Test("한 순간 초안을 저장·삭제·비워도 다른 초안은 재실행 후까지 보존한다", arguments: ["publish", "discard", "erase"])
    func completesOnlySelectedDraft(action: String) throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        let first = photoDraft(title: "남겨 둘 글", text: "보관할 본문", emotion: "평온", bytes: [1, 2])
        var selected = photoDraft(title: "선택한 글", text: "선택한 본문", emotion: "기쁨", bytes: [3, 4])
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.save(first))
            #expect(store.writingDraftStore.save(selected))
            switch action {
            case "publish":
                let saved = try #require(store.saveMomentDraft(selected))
                #expect(store.diaryDocument(for: saved) == selected.diaryDocument)
            case "discard":
                #expect(store.writingDraftStore.discard(id: selected.id))
            default:
                selected.title = ""
                selected.emotion = nil
                selected.setDiaryDocument(DiaryDocument(text: ""))
                #expect(store.writingDraftStore.save(selected))
            }
            #expect(store.writingDraftStore.momentDrafts == [first])
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.writingDraftStore.momentDrafts == [first])
        #expect(reopened.writingDraftStore.count == 1)
        #expect(reopened.records.count == (action == "publish" ? 1 : 0))
    }

    @Test("이전 단일 순간 초안을 유지하면서 새 초안을 추가하고 기존 초안을 중복 없이 수정한다")
    func preservesLegacySingleDraft() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        var legacy = RecordDraft(title: "이전 초안", content: "예전에 쓰던 글", emotion: "슬픔", photoData: Data([7, 8]))
        do {
            let container = try ModelContainer(for: Schema(versionedSchema: WhisperSchemaV7.self), configurations: configuration)
            var metadata = legacy
            metadata.photoData = nil
            let row = WritingDraft(id: legacy.id, storageKey: "moment",
                payload: try JSONEncoder().encode(metadata), photoData: legacy.photoData)
            row.updatedAt = .now.addingTimeInterval(-86_400)
            container.mainContext.insert(row)
            try container.mainContext.save()
        }
        let newDraft = photoDraft(title: "새 초안", text: "새로 쓰는 글", emotion: "기쁨", bytes: [9, 10])
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.momentDrafts == [legacy])
            #expect(store.writingDraftStore.save(newDraft))
            #expect(store.writingDraftStore.momentDrafts.first { $0.id == legacy.id } == legacy)
            legacy.content = "이전 글에 이어 쓴 문장"
            #expect(store.writingDraftStore.save(legacy))
            #expect(store.writingDraftStore.count == 2)
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.writingDraftStore.momentDrafts == [legacy, newDraft])
        #expect(reopened.writingDraftStore.count == 2)
        let container = try ModelContainer(for: Schema(versionedSchema: WhisperSchemaV7.self), configurations: configuration)
        let rows = try container.mainContext.fetch(FetchDescriptor<WritingDraft>())
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.storageKey != "moment" })
    }

    @Test("여러 초안의 저장 실패 중에도 최신 글과 사진을 각각 유지하고 모두 재시도한다")
    func retriesIndependentPendingMoments() throws {
        let container = try ModelContainer(for: Schema(versionedSchema: WhisperSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var shouldFail = false
        let drafts = WritingDraftStore(context: container.mainContext) { context in
            if shouldFail { throw SaveFailure.unavailable }
            try context.save()
        }
        var first = photoDraft(title: "첫 글", text: "처음 저장한 첫 글", emotion: "평온", bytes: [1])
        var second = photoDraft(title: "둘째 글", text: "처음 저장한 둘째 글", emotion: "기쁨", bytes: [2])
        #expect(drafts.save(first))
        #expect(drafts.save(second))
        let persistedFirst = first
        let persistedSecond = second
        shouldFail = true
        first.setDiaryDocument(DiaryDocument(text: "실패 중 최신 첫 글", photos: [DiaryPhoto(offset: 3, data: Data([3]))]))
        second.setDiaryDocument(DiaryDocument(text: "실패 중 최신 둘째 글", photos: [DiaryPhoto(offset: 3, data: Data([4]))]))
        #expect(!drafts.save(first))
        #expect(!drafts.save(second))
        drafts.reload()
        #expect(drafts.count == 2)
        #expect(drafts.momentDrafts.first { $0.id == first.id } == first)
        #expect(drafts.momentDrafts.first { $0.id == second.id } == second)
        #expect(drafts.errorMessage != nil)
        let persisted = WritingDraftStore(context: container.mainContext)
        #expect(persisted.momentDrafts.first { $0.id == first.id } == persistedFirst)
        #expect(persisted.momentDrafts.first { $0.id == second.id } == persistedSecond)
        shouldFail = false
        drafts.retry()
        #expect(drafts.errorMessage == nil)
        let reopened = WritingDraftStore(context: container.mainContext)
        #expect(reopened.count == 2)
        #expect(reopened.momentDrafts.first { $0.id == first.id } == first)
        #expect(reopened.momentDrafts.first { $0.id == second.id } == second)
    }

    @Test("새 순간의 최종 저장이 실패하면 기존 초안과 새 초안을 함께 유지하고 재시도 시 해당 초안만 완료한다")
    func failedPublishKeepsOtherDrafts() throws {
        var attempt = 0
        var failingAttempt: Int?
        let store = RecordStore(isStoredInMemoryOnly: true) { context in
            attempt += 1
            if attempt == failingAttempt { throw SaveFailure.unavailable }
            try context.save()
        }
        let first = photoDraft(title: "기존 초안", text: "보관할 본문", emotion: "평온", bytes: [1])
        let selected = photoDraft(title: "새 순간", text: "저장할 본문", emotion: "기쁨", bytes: [2])
        #expect(store.writingDraftStore.save(first))
        #expect(store.writingDraftStore.save(selected))
        failingAttempt = attempt + 2
        #expect(store.saveMomentDraft(selected) == nil)
        #expect(store.records.isEmpty)
        #expect(store.writingDraftStore.momentDrafts.first { $0.id == first.id } == first)
        #expect(store.writingDraftStore.momentDrafts.first { $0.id == selected.id } == selected)
        failingAttempt = nil
        #expect(store.saveMomentDraft(selected)?.id == selected.id)
        #expect(store.writingDraftStore.momentDrafts == [first])
        #expect(store.records.count == 1)
    }

    private func photoDraft(title: String, text: String, emotion: String, bytes: [UInt8]) -> RecordDraft {
        var draft = RecordDraft(title: title, emotion: emotion)
        draft.setDiaryDocument(DiaryDocument(text: text, photos: [DiaryPhoto(offset: 3, data: Data(bytes))]))
        return draft
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "NewMomentDraftTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func configuration(at directory: URL) -> ModelConfiguration {
        ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self),
            url: directory.appending(path: "default.store"), cloudKitDatabase: .none)
    }
}
