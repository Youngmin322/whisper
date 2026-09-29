import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("순간 작성 내용 보존", .serialized)
struct RecordDraftTests {
    @Test("한 화면에서 제목과 사진을 더해도 긴 본문과 감정 선택을 보존한다")
    func keepsOneDraftWithOptionalDetails() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let content = String(repeating: "오늘의 장면 ", count: 60)
        let photo = Data([0x01, 0x02, 0x03])
        var draft = RecordDraft(content: content, emotion: "기쁨")

        draft.title = "집에 돌아오던 길"
        draft.photoData = photo
        draft.emotion = nil

        #expect(draft.canSave)
        #expect(draft.content == content)
        #expect(draft.emotion == nil)
        let saved = try #require(store.addAndReturn(
            title: draft.titleForSaving,
            content: draft.contentForSaving,
            emotion: draft.emotion,
            photoData: draft.photoData
        ))
        #expect(saved.content == content.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(saved.title == "집에 돌아오던 길")
        #expect(saved.emotion == nil)
        #expect(saved.photoData == photo)
    }

    @Test("길이 초과로 저장할 수 없어도 사용자가 쓴 내용은 자르지 않는다")
    func preservesOverLimitText() {
        let content = String(repeating: "가", count: RecordDraft.contentLimit + 1)
        let draft = RecordDraft(content: content)

        #expect(!draft.canSave)
        #expect(draft.content == content)
        #expect(draft.hasChanges)
    }

    @Test("새 순간은 감정과 본문을 모두 선택해야 저장할 수 있다")
    func requiresEmotionForNewMoment() {
        var draft = RecordDraft(content: "오늘 친구와 산책했다.")

        #expect(draft.canSave)
        #expect(!draft.canSaveNewMoment)

        draft.emotion = "기쁨"
        #expect(draft.canSaveNewMoment)

        draft.content = "  "
        #expect(!draft.canSaveNewMoment)
    }
}
