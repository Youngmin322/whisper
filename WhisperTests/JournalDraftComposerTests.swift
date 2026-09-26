import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("하루의 순간을 원문 그대로 모으기", .serialized)
struct JournalDraftComposerTests {
    @Test("시간 순서대로 원문을 담고 다른 날의 기록은 제외한다")
    func copiesExactWordsInTimeOrder() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let day = Calendar.current.startOfDay(for: .now)
        let morning = try #require(store.addAndReturn(
            title: "아침", content: "  첫 문장\n그대로  ",
            createdAt: day.addingTimeInterval(9 * 3600), emotion: "평온"
        ))
        let evening = try #require(store.addAndReturn(
            title: "저녁", content: "둘째 문장!",
            createdAt: day.addingTimeInterval(18 * 3600), emotion: "기쁨"
        ))
        _ = store.addAndReturn(
            title: "어제", content: "포함되면 안 됨",
            createdAt: day.addingTimeInterval(-3600)
        )

        let draft = JournalDraftComposer.compose(on: day, records: store.records, existing: nil)
        #expect(draft.body == "  첫 문장\n그대로  \n\n둘째 문장!")
        #expect(draft.sourceRecordIDs == [morning.id, evening.id])
        #expect(draft.representativeEmotion == "기쁨")
    }

    @Test("기존 일기에는 새 순간만 추가하며 사용자가 쓴 내용은 보존한다")
    func appendsOnlyNewMoments() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let day = Calendar.current.startOfDay(for: .now)
        let first = try #require(store.addAndReturn(
            title: "첫째", content: "처음 기록", createdAt: day.addingTimeInterval(3600)
        ))
        let journal = try #require(store.saveJournal(
            on: day, title: "내 제목", body: "처음 기록\n\n내가 덧붙인 글",
            sourceRecordIDs: [first.id]
        ))
        let second = try #require(store.addAndReturn(
            title: "둘째", content: "다음 기록", createdAt: day.addingTimeInterval(7200)
        ))

        let draft = JournalDraftComposer.compose(on: day, records: store.records, existing: journal)
        #expect(draft.body == "처음 기록\n\n내가 덧붙인 글\n\n다음 기록")
        #expect(draft.sourceRecordIDs == [first.id, second.id])
        #expect(draft.title == "내 제목")
    }
}
