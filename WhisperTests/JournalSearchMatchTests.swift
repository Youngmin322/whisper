import SwiftUI
import Testing
@testable import Whisper

@MainActor
@Suite("일기 중심의 검색 일치 문장")
struct JournalSearchMatchTests {
    @Test("긴 일기에서는 검색어 주변을 보여주고 모든 일치 부분을 강조한다")
    func excerptsAndHighlightsJournalBody() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let body = String(repeating: "앞부분의 기억 👨‍👩‍👧‍👦. ", count: 20)
            + "민수와 강변에서 산책했다. 민수는 즐거워했다. " + String(repeating: "다음 기억. ", count: 30)
        let journal = try #require(store.saveJournal(on: .now, title: "하루", body: body, sourceRecordIDs: []))
        let result = try #require(index(store).results(matching: " 민수 \n").first)
        #expect(result.recordID == journal.id && result.kind == .journal)
        #expect(result.preview.hasPrefix("…") && result.preview.hasSuffix("…"))
        #expect(result.preview.contains("민수와 강변에서 산책했다"))
        #expect(result.preview.count < body.count)
        let context = try #require(result.searchContext)
        #expect(context.description(for: .journal) == (isEnglish ? "Found in the entry text" : "일기 본문에서 찾았어요"))
        #expect(!context.opensSources)
        let highlighted = JournalSearchHighlightedText(text: result.preview, query: context.query).highlighted
        #expect(highlighted.runs.filter { $0.backgroundColor != nil }.count == 2)
        #expect(String(highlighted.characters) == result.preview)
        #expect(journal.body == body)
    }

    @Test("여러 원본에서만 찾은 문장은 하나의 일기로 묶고 관련 원본을 모두 전달한다")
    func groupsMatchingSourcesIntoOneJournal() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let first = try #require(store.addAndReturn(title: "산책", content: "민수와 강변에서 산책했다."))
        let second = try #require(store.addAndReturn(title: "저녁", content: "민수와 저녁을 먹었다."))
        let journal = try #require(store.saveJournal(on: .now, title: "편안한 하루", body: "오늘은 편안했다.",
                                                    sourceRecordIDs: [first.id, second.id]))
        let results = index(store).results(matching: "민수")
        #expect(results.count == 1)
        let result = try #require(results.first)
        #expect(result.recordID == journal.id && result.kind == .journal)
        #expect(result.title == journal.title)
        #expect(result.preview == first.content)
        let context = try #require(result.searchContext)
        #expect(context.opensSources)
        #expect(context.sourceIDs == [first.id, second.id])
        #expect(context.matches.contains { $0.sourceID == second.id && $0.snippet == second.content })
        #expect(context.description(for: .journal) == (isEnglish ? "Found in 2 moments from this entry" : "담아 둔 순간 2개에서 찾았어요"))
        #expect(journal.body == "오늘은 편안했다.")
        #expect(first.content == "민수와 강변에서 산책했다.")
    }

    @Test("일기에도 검색어가 있으면 원본보다 일기 본문을 먼저 보여준다")
    func prefersFinishedJournal() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let source = try #require(store.addAndReturn(title: "민수", content: "민수와 산책했다."))
        let journal = try #require(store.saveJournal(on: .now, title: "민수와 보낸 하루", body: "민수 덕분에 편안했다.",
                                                    sourceRecordIDs: [source.id]))
        let result = try #require(index(store).results(matching: "민수").first)
        #expect(result.preview == journal.body)
        #expect(result.searchContext?.matches.first?.field == .body)
        #expect(result.searchContext?.opensSources == false)
        #expect(result.searchContext?.sourceIDs == [source.id])
    }

    @Test("제목·감정으로만 찾은 결과도 일치한 필드와 문구를 보여준다")
    func matchesTitleAndEmotion() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        _ = try #require(store.saveJournal(on: .now, title: "서울 여행", body: "햇살이 좋았다.", sourceRecordIDs: [], emotion: "기쁨"))
        let title = try #require(index(store).results(matching: "서울").first)
        #expect(title.preview == "서울 여행")
        #expect(title.searchContext?.description(for: .journal) == (isEnglish ? "Found in the entry title" : "일기 제목에서 찾았어요"))
        let emotion = try #require(index(store).results(matching: "기쁨").first)
        #expect(emotion.preview == "기쁨")
        #expect(emotion.searchContext?.description(for: .journal) == (isEnglish ? "Matched this entry's emotion" : "일기 감정에서 찾았어요"))
    }

    @Test("원본 삭제 후에는 그 원본에서만 일치했던 검색 결과를 남기지 않는다")
    func removesDeletedSourceMatches() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let source = try #require(store.addAndReturn(title: "산책", content: "민수와 산책했다."))
        let journal = try #require(store.saveJournal(on: .now, title: "편안한 하루", body: "오늘은 편안했다.", sourceRecordIDs: [source.id]))
        #expect(index(store).results(matching: "민수").count == 1)
        #expect(store.delete(source))
        #expect(index(store).results(matching: "민수").isEmpty)
        #expect(index(store).results(matching: "편안").first?.recordID == journal.id)
        #expect(journal.body == "오늘은 편안했다.")
    }

    @Test("미보관 순간과 빈 검색은 유지하고 영문 대소문자와 이모지 문맥을 처리한다")
    func preservesUncollectedAndEmptySearch() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let moment = try #require(store.addAndReturn(title: "산책", content: "👨‍👩‍👧‍👦 Coffee를 마시며 쉬었다."))
        let result = try #require(index(store).results(matching: " coffee ").first)
        #expect(result.kind == .moment && result.recordID == moment.id)
        #expect(result.preview.contains("Coffee"))
        #expect(result.searchContext?.description(for: .moment) == (isEnglish ? "Found in the moment text" : "순간 본문에서 찾았어요"))
        #expect(!JournalSearchHighlightedText(text: result.preview, query: "coffee").highlighted.runs.filter { $0.backgroundColor != nil }.isEmpty)
        let all = try #require(index(store).results(matching: " \n ").first)
        #expect(all.preview == moment.content && all.searchContext == nil)
        #expect(JournalSearchSnippet.make(in: "👨‍👩‍👧‍👦 민수", query: "민수") == "👨‍👩‍👧‍👦 민수")
    }

    private var isEnglish: Bool { Bundle.main.preferredLocalizations.first == "en" }

    private func index(_ store: RecordStore) -> JournalArchiveIndex {
        JournalArchiveIndex(records: store.records, journals: store.journals)
    }
}
