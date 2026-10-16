import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("지난날의 일기와 미보관 순간 탐색", .serialized)
struct JournalArchiveTests {
    private enum SaveFailure: Error { case unavailable }

    @Test("달력에서 일기·미보관 순간·둘 다 있는 날짜를 구분하고 빈 날짜는 제외한다")
    func calendarIncludesAllSavedKinds() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let first = day("2026-09-28")
        let second = day("2026-09-29")
        let third = day("2026-09-30")
        let moment = try #require(store.addAndReturn(title: "지난 순간", content: "못 담은 순간", createdAt: first.date.addingTimeInterval(3600)))
        let collected = try #require(store.addAndReturn(title: "원본", content: "담은 순간", createdAt: second.date.addingTimeInterval(3600)))
        let journal = try #require(store.saveJournal(on: second, title: "담긴 날", body: collected.content, sourceRecordIDs: [collected.id]))
        let mixedSource = try #require(store.addAndReturn(title: "먼저 담은 순간", content: "담긴 원문", createdAt: third.date.addingTimeInterval(3600)))
        _ = try #require(store.saveJournal(on: third, title: "둘 다 있는 날", body: mixedSource.content, sourceRecordIDs: [mixedSource.id]))
        let newMoment = try #require(store.addAndReturn(title: "나중 순간", content: "새 원문", createdAt: third.date.addingTimeInterval(7200)))

        let index = archive(store, calendar: first.calendar)
        #expect(index.days.map(\.id) == [third.key, second.key, first.key])
        let momentDay = try #require(index.entry(for: first.key))
        #expect(!momentDay.hasJournal && momentDay.hasUncollectedMoments)
        #expect(momentDay.uncollectedMoments.map(\.id) == [moment.id])
        let journalDay = try #require(index.entry(for: second.key))
        #expect(journalDay.journals.map(\.id) == [journal.id])
        #expect(journalDay.hasJournal && !journalDay.hasUncollectedMoments)
        let both = try #require(index.entry(for: third.key))
        #expect(both.hasJournal && both.hasUncollectedMoments)
        #expect(both.uncollectedMoments.map(\.id) == [newMoment.id])
        #expect(index.entry(for: "2026-10-01") == nil)
        #expect(both.accessibilityDescription.contains(Bundle.main.preferredLocalizations.first == "en" ? "1 saved day" : "담긴 하루 1개"))
        #expect(both.accessibilityDescription.contains(Bundle.main.preferredLocalizations.first == "en" ? "1 uncollected moment" : "아직 담지 않은 순간 1개"))
    }

    @Test("일기를 하나도 만들지 않아도 미보관 순간을 제목·내용·감정으로 검색한다")
    func searchesUncollectedMomentsWithoutAnyJournals() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let yesterday = day("2026-09-30")
        let record = try #require(store.addAndReturn(title: "Coffee 산책", content: "강변에서 웃었던 기억",
                                                    createdAt: yesterday.date.addingTimeInterval(3600), emotion: "기쁨"))
        _ = store.addAndReturn(title: "다른 순간", content: "책 읽기", createdAt: yesterday.nextBoundary.addingTimeInterval(3600), emotion: "평온")
        let index = archive(store, calendar: yesterday.calendar)
        for query in [" coffee ", "웃었던", "기쁨"] {
            let result = try #require(index.results(matching: query).first)
            #expect(index.results(matching: query).count == 1)
            #expect(result.kind == .moment)
            #expect(result.recordID == record.id)
            #expect(result.day.key == yesterday.key)
        }
        #expect(index.results(matching: "   ").count == 2)
        #expect(index.results(matching: "없는 내용").isEmpty)
    }

    @Test("담긴 원본은 연결된 일기를 검색하고 미보관 순간만 별도 결과로 표시한다")
    func searchKeepsJournalSourcesAndUncollectedResultsSeparate() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let target = day("2026-09-30")
        let source = try #require(store.addAndReturn(title: "원본에서만 찾는 제목", content: "복사 전 원문", createdAt: target.date.addingTimeInterval(3600)))
        let journal = try #require(store.saveJournal(on: target, title: "일기 제목", body: "직접 고친 일기",
                                                    sourceRecordIDs: [source.id], emotion: "평온"))
        journal.reflection = "회고에만 있는 단어"
        let standalone = try #require(store.addAndReturn(title: "새로운 원본", content: "직접 고친 일기와 같은 단어",
                                                        createdAt: target.date.addingTimeInterval(7200)))
        let index = archive(store, calendar: target.calendar)
        #expect(index.results(matching: "원본에서만").map(\.recordID) == [journal.id])
        #expect(index.results(matching: "회고에만").map(\.recordID) == [journal.id])
        let all = index.results(matching: "고친 일기")
        #expect(all.map(\.kind) == [.journal, .moment])
        #expect(all.map(\.recordID) == [journal.id, standalone.id])
        #expect(!index.results(matching: "").contains { $0.recordID == source.id })
    }

    @Test("지난날의 새 일기와 기존 일기에 순간을 담아도 원본·날짜·대표 감정을 보존한다", arguments: [false, true])
    func collectsPastMoments(existing: Bool) throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let target = day("2026-09-29")
        let photo = Data([1, 2, 3])
        let first = try #require(store.addAndReturn(title: "첫 순간", content: "첫 원문", createdAt: target.date.addingTimeInterval(3600), emotion: "평온", photoData: photo))
        var journal: DailyJournal?
        if existing {
            let saved = try #require(store.saveJournal(on: target, title: "기존 제목", body: "직접 고친 기존 본문",
                                                       sourceRecordIDs: [first.id], emotion: "슬픔"))
            journal = saved
        }
        let second = try #require(store.addAndReturn(title: "새 순간", content: "새 원문", createdAt: target.date.addingTimeInterval(7200), emotion: "기쁨"))
        let entry = try #require(archive(store, calendar: target.calendar).entry(for: target.key))
        #expect(entry.canCollect)
        #expect(entry.collectionTitle == (Bundle.main.preferredLocalizations.first == "en"
            ? (existing ? "Add 1 new moment" : "Gather this day's moments")
            : (existing ? "새 순간 1개 함께 담기" : "이날의 순간 병에 담기")))
        let draft = JournalWritingDraft(day: entry.day, existing: entry.journals.first, records: entry.uncollectedMoments)
        #expect(draft.body == (existing ? "직접 고친 기존 본문\n\n새 원문" : "첫 원문\n\n새 원문"))
        // Opening and closing an editor only saves a draft, not a collected journal.
        #expect(store.writingDraftStore.save(draft))
        #expect(archive(store, calendar: target.calendar).entry(for: target.key)?.uncollectedMoments.count == (existing ? 1 : 2))
        let saved = try #require(store.saveJournalDraft(draft))
        #expect(saved.dayKey == target.key)
        #expect(saved.date == target.date)
        #expect(saved.sourceRecordIDs == [first.id, second.id])
        if existing {
            #expect(saved.id == journal?.id)
            #expect(saved.title == "기존 제목")
            #expect(saved.emotion == "슬픔")
        }
        #expect(store.record(withID: first.id)?.photoData == photo)
        #expect(store.record(withID: first.id)?.content == "첫 원문")
        #expect(store.record(withID: second.id)?.content == "새 원문")
        let after = try #require(archive(store, calendar: target.calendar).entry(for: target.key))
        #expect(after.hasJournal && !after.hasUncollectedMoments)
        #expect(archive(store, calendar: target.calendar).results(matching: "새 원문").map(\.recordID) == [saved.id])
        #expect(store.saveJournalDraft(draft)?.sourceRecordIDs == [first.id, second.id])
        #expect(store.journals.count == 1)
    }

    @Test("지난날 병에 담기 저장 실패 시 달력과 검색에서 순간이 미보관 상태로 남는다", arguments: [false, true])
    func failedCollectionRemainsDiscoverable(existing: Bool) throws {
        var attempts = 0
        var failAt: Int?
        let store = RecordStore(isStoredInMemoryOnly: true) { context in
            attempts += 1
            if attempts == failAt { throw SaveFailure.unavailable }
            try context.save()
        }
        let target = day("2026-09-29")
        let first = try #require(store.addAndReturn(title: "원본", content: "먼저 담은 글", createdAt: target.date.addingTimeInterval(3600)))
        if existing {
            _ = try #require(store.saveJournal(on: target, title: "기존", body: "수동 일기 본문",
                                              sourceRecordIDs: [first.id], emotion: "평온"))
        }
        let second = try #require(store.addAndReturn(title: "찾을 순간", content: "찾아야 하는 원문", createdAt: target.date.addingTimeInterval(7200)))
        let before = try #require(archive(store, calendar: target.calendar).entry(for: target.key))
        let draft = JournalWritingDraft(day: target, existing: before.journals.first, records: before.uncollectedMoments)
        failAt = attempts + 2
        #expect(store.saveJournalDraft(draft) == nil)
        let after = try #require(archive(store, calendar: target.calendar).entry(for: target.key))
        #expect(after.uncollectedMoments.map(\.id) == before.uncollectedMoments.map(\.id))
        #expect(after.journals.count == (existing ? 1 : 0))
        if existing { #expect(after.journals.first?.body == "수동 일기 본문") }
        #expect(archive(store, calendar: target.calendar).results(matching: "찾아야").map(\.recordID) == [second.id])
        #expect(store.writingDraftStore.journalDrafts.first?.id == draft.id)
        failAt = nil
        #expect(store.saveJournalDraft(draft) != nil)
        #expect(archive(store, calendar: target.calendar).entry(for: target.key)?.hasUncollectedMoments == false)
    }

    @Test("과거 일기를 삭제하면 사진을 포함한 원본 순간을 달력과 검색에서 다시 찾는다")
    func deletingJournalReturnsSourcesToCalendarAndSearch() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let target = day("2026-09-29")
        let photo = Data([4, 5])
        let original = try #require(store.addAndReturn(title: "원본 제목", content: "다시 찾는 원문",
                                                      createdAt: target.date.addingTimeInterval(3600), photoData: photo))
        let journal = try #require(store.saveJournal(on: target, title: "일기 제목", body: "직접 수정한 일기",
                                                    sourceRecordIDs: [original.id]))
        #expect(store.deleteJournal(journal))
        #expect(store.refreshPersistentState())
        let entry = try #require(archive(store, calendar: target.calendar).entry(for: target.key))
        #expect(!entry.hasJournal && entry.hasUncollectedMoments)
        #expect(entry.uncollectedMoments.map(\.id) == [original.id])
        #expect(entry.uncollectedMoments.first?.photoData == photo)
        let result = try #require(archive(store, calendar: target.calendar).results(matching: "다시 찾는").first)
        #expect(result.recordID == original.id && result.kind == .moment)
        #expect(store.record(withID: result.recordID)?.content == "다시 찾는 원문")
    }

    @Test("시간대가 바뀌어 원본의 현지 날짜가 달라져도 이미 담긴 순간을 다시 노출하지 않는다")
    func timeZoneChangeDoesNotDuplicateCollectedSources() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let seoul = day("2026-10-01")
        let losAngeles = day("2026-09-30", zone: "America/Los_Angeles")
        let collected = try #require(store.addAndReturn(title: "서울에서 담은 순간", content: "이미 담긴 글", createdAt: seoul.date))
        let journal = try #require(store.saveJournal(on: seoul, title: "서울의 하루", body: collected.content, sourceRecordIDs: [collected.id]))
        let newMoment = try #require(store.addAndReturn(title: "LA에서 새 순간", content: "새로 담을 글", createdAt: losAngeles.date.addingTimeInterval(3600)))
        let index = archive(store, calendar: losAngeles.calendar)
        #expect(index.entry(for: seoul.key)?.journals.map(\.id) == [journal.id])
        let entry = try #require(index.entry(for: losAngeles.key))
        #expect(entry.uncollectedMoments.map(\.id) == [newMoment.id])
        #expect(index.results(matching: "서울에서").map(\.recordID) == [journal.id])
    }

    @Test("같은 날짜의 레거시 일기들은 모두 열람·검색할 수 있고 임의로 합치지 않는다")
    func legacyDuplicatesRemainSeparate() {
        let target = day("2026-10-01")
        let first = DailyJournal(dayKey: target.key, date: target.date, title: "첫 일기", body: "첫 원문", reflection: "", sourceRecordIDs: [])
        let legacy = DailyJournal(dayKey: "2569-10-01", date: target.date, title: "이전 일기", body: "둘째 원문", reflection: "", sourceRecordIDs: [])
        let moment = WhisperRecord(title: "추가 순간", content: "새 글", createdAt: target.date.addingTimeInterval(3600))
        let index = JournalArchiveIndex(records: [moment], journals: [first, legacy], calendar: target.calendar)
        #expect(Set(index.entry(for: target.key)?.journals.map(\.id) ?? []) == Set([first.id, legacy.id]))
        #expect(index.entry(for: target.key)?.canCollect == false)
        #expect(Set(index.results(matching: "원문").map(\.recordID)) == Set([first.id, legacy.id]))
    }

    private func archive(_ store: RecordStore, calendar: Calendar) -> JournalArchiveIndex {
        JournalArchiveIndex(records: store.records, journals: store.journals, calendar: calendar)
    }

    private func day(_ key: String, zone: String = "Asia/Seoul") -> JournalDay {
        let calendar = JournalDayKey.calendar(timeZone: TimeZone(identifier: zone)!)
        return JournalDay(date: JournalDayKey.date(for: key, timeZone: calendar.timeZone)!, calendar: calendar)
    }
}
