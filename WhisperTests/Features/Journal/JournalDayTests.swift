import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("일기 날짜와 자정 경계", .serialized)
struct JournalDayTests {
    private func calendar(_ zone: String, identifier: Calendar.Identifier = .gregorian) throws -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        return calendar
    }

    private func date(_ key: String, in calendar: Calendar) throws -> Date {
        try #require(JournalDayKey.date(for: key, timeZone: calendar.timeZone))
    }

    @Test("불교력으로 바꿔도 조회와 저장은 같은 일기를 사용한다")
    func changingCalendarKeepsJournalIdentity() throws {
        let gregorian = try calendar("Asia/Seoul")
        let buddhist = try calendar("Asia/Seoul", identifier: .buddhist)
        let today = try date("2026-10-01", in: gregorian)
        let store = RecordStore(isStoredInMemoryOnly: true)
        let journal = try #require(store.saveJournal(on: today, title: "제목", body: "본문", sourceRecordIDs: [], calendar: gregorian))
        journal.reflection = "회고"
        #expect(store.journal(on: today, calendar: buddhist)?.id == journal.id)
        let updated = try #require(store.saveJournal(on: today, title: "수정", body: "새 본문", sourceRecordIDs: [], calendar: buddhist))
        #expect(updated.id == journal.id)
        #expect(updated.dayKey == "2026-10-01")
        #expect(updated.reflection == "회고")
        #expect(store.journals.count == 1)
    }

    @Test("시간대가 바뀌어도 작성 당시 날짜로 조회·수정한다", arguments: [
        ["Asia/Seoul", "America/Los_Angeles"], ["America/Los_Angeles", "Asia/Seoul"]
    ])
    func changingTimeZoneKeepsCivilDay(zones: [String]) throws {
        let original = try calendar(zones[0])
        let changed = try calendar(zones[1])
        let store = RecordStore(isStoredInMemoryOnly: true)
        let sourceID = UUID()
        let journal = try #require(store.saveJournal(
            on: date("2026-10-01", in: original), title: "제목", body: "보존할 글", sourceRecordIDs: [sourceID],
            emotion: "평온", calendar: original
        ))
        journal.reflection = "보존할 회고"
        let changedDate = try date("2026-10-01", in: changed)
        #expect(store.journal(on: changedDate, calendar: changed)?.id == journal.id)
        let updated = try #require(store.saveJournal(
            on: changedDate, title: journal.title, body: journal.body, sourceRecordIDs: journal.sourceRecordIDs, calendar: changed
        ))
        #expect(updated.id == journal.id)
        #expect(updated.dayKey == "2026-10-01")
        #expect(updated.emotion == "평온")
        #expect(updated.reflection == "보존할 회고")
        #expect(updated.sourceRecordIDs == [sourceID])
        #expect(store.journals.count == 1)
        #expect(store.refreshPersistentState())
        #expect(store.journal(on: changedDate, calendar: changed)?.body == "보존할 글")
    }

    @Test("서울의 10월 1일 일기가 LA에서 9월 30일 일기로 잘못 조회되지 않는다")
    func neighboringDayDoesNotOverwriteJournal() throws {
        let seoul = try calendar("Asia/Seoul")
        let losAngeles = try calendar("America/Los_Angeles")
        let store = RecordStore(isStoredInMemoryOnly: true)
        let first = try #require(store.saveJournal(on: date("2026-10-01", in: seoul), title: "1일", body: "첫 일기", sourceRecordIDs: [], calendar: seoul))
        let september = try date("2026-09-30", in: losAngeles)
        #expect(store.journal(on: september, calendar: losAngeles) == nil)
        let second = try #require(store.saveJournal(on: september, title: "30일", body: "둘째 일기", sourceRecordIDs: [], calendar: losAngeles))
        #expect(second.id != first.id)
        #expect(first.body == "첫 일기")
        #expect(store.journals.count == 2)
    }

    @Test("시간대 차이로 저장 시각 순서가 뒤집혀도 일기는 작성 날짜순으로 정렬한다")
    func journalOrderUsesCivilDate() throws {
        let west = try calendar("Etc/GMT+12")
        let east = try calendar("Pacific/Kiritimati")
        let store = RecordStore(isStoredInMemoryOnly: true)
        _ = try #require(store.saveJournal(on: date("2026-10-01", in: west), title: "1일", body: "첫째", sourceRecordIDs: [], calendar: west))
        _ = try #require(store.saveJournal(on: date("2026-10-02", in: east), title: "2일", body: "둘째", sourceRecordIDs: [], calendar: east))
        #expect(store.journals.map(\.civilDayKey) == ["2026-10-02", "2026-10-01"])
    }

    @Test("이전 버전의 시스템 달력 키는 저장 날짜를 이용해 복원한다", arguments: [
        Calendar.Identifier.buddhist, .japanese, .republicOfChina, .chinese, .hebrew,
        .islamic, .islamicCivil, .islamicTabular, .islamicUmmAlQura, .persian,
        .indian, .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem, .iso8601
    ])
    func recoversSupportedLegacyCalendars(identifier: Calendar.Identifier) throws {
        let gregorian = try calendar("Asia/Seoul")
        let original = try calendar("Asia/Seoul", identifier: identifier)
        let storedDate = try date("2026-10-01", in: gregorian)
        let parts = original.dateComponents([.year, .month, .day], from: storedDate)
        let oldKey = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        #expect(JournalDayKey.persistedKey(oldKey, date: storedDate) == "2026-10-01")
    }

    @Test("이전 버전의 불교력 키를 Gregorian 날짜로 찾아 원래 ID와 내용을 보존한다", arguments: ["Asia/Seoul", "America/Los_Angeles"])
    func readsLegacyCalendarKey(zone: String) throws {
        let original = try calendar(zone)
        let target = try calendar("UTC")
        let store = RecordStore(isStoredInMemoryOnly: true)
        let sourceID = UUID()
        let journal = try #require(store.saveJournal(on: date("2026-10-01", in: original), title: "기존", body: "본문", sourceRecordIDs: [sourceID], emotion: "기쁨", calendar: original))
        journal.dayKey = "2569-10-01"
        journal.reflection = "회고"
        let targetDate = try date("2026-10-01", in: target)
        #expect(store.journal(on: targetDate, calendar: target)?.id == journal.id)
        let updated = try #require(store.saveJournal(on: targetDate, title: "수정", body: journal.body, sourceRecordIDs: journal.sourceRecordIDs, calendar: target))
        #expect(updated.id == journal.id)
        #expect(updated.dayKey == "2569-10-01")
        #expect(updated.civilDayKey == "2026-10-01")
        #expect(JournalDayKey.make(for: updated.displayDate) == "2026-10-01")
        #expect(updated.sourceRecordIDs == [sourceID])
        #expect(updated.emotion == "기쁨")
        #expect(updated.reflection == "회고")
        #expect(store.refreshPersistentState())
        #expect(store.journal(on: targetDate, calendar: target)?.id == updated.id)
        #expect(store.journals.count == 1)
    }

    @Test("같은 날로 복원되는 기존 일기가 여러 개면 자동 병합하지 않고 ID로 수정한다")
    func legacyDuplicatesAreNotMerged() throws {
        let calendar = try calendar("Asia/Seoul")
        let targetDate = try date("2026-10-01", in: calendar)
        let day = JournalDay(date: targetDate, calendar: calendar)
        let store = RecordStore(isStoredInMemoryOnly: true)
        let first = try #require(store.saveJournal(on: targetDate, title: "첫째", body: "첫 본문", sourceRecordIDs: [], calendar: calendar))
        let second = try #require(store.saveJournal(on: date("2026-10-02", in: calendar), title: "둘째", body: "둘째 본문", sourceRecordIDs: [], calendar: calendar))
        second.date = targetDate
        second.dayKey = "2569-10-01"
        #expect(store.saveJournal(on: day, title: "", body: "덮어쓰기", sourceRecordIDs: []) == nil)
        let edited = try #require(store.saveJournal(on: day, existingJournalID: second.id, title: "둘째 수정", body: second.body, sourceRecordIDs: []))
        #expect(edited.id == second.id)
        #expect(first.body == "첫 본문")
        #expect(edited.body == "둘째 본문")
        #expect(store.journals.count == 2)
    }

    @Test("복원할 수 없는 기존 키와 충돌하면 새 일기가 기존 내용을 덮어쓰지 않는다")
    func invalidLegacyKeyCannotTriggerUniqueUpsert() throws {
        let calendar = try calendar("UTC")
        let store = RecordStore(isStoredInMemoryOnly: true)
        let journal = try #require(store.saveJournal(on: date("2026-09-01", in: calendar), title: "보존", body: "중요한 글", sourceRecordIDs: [], calendar: calendar))
        journal.dayKey = "2026-10-01"
        #expect(journal.civilDayKey == nil)
        let targetDate = try date("2026-10-01", in: calendar)
        #expect(store.saveJournal(on: targetDate, title: "새 일기", body: "새 글", sourceRecordIDs: [], calendar: calendar) == nil)
        #expect(journal.body == "중요한 글")
        #expect(store.journals.count == 1)
    }

    @Test("자정 직전 담기 시작한 초안과 저장 대상은 다음 날에도 원래 날을 유지한다")
    func collectionKeepsDayAcrossMidnight() throws {
        let calendar = try calendar("Asia/Seoul")
        let originalDate = try date("2026-10-01", in: calendar)
        let day = JournalDay(date: originalDate.addingTimeInterval(86_399.5), calendar: calendar)
        let afterMidnight = day.nextBoundary.addingTimeInterval(0.32)
        let store = RecordStore(isStoredInMemoryOnly: true)
        let original = try #require(store.addAndReturn(title: "", content: "담기 시작한 순간", createdAt: day.date.addingTimeInterval(80_000)))
        let next = try #require(store.addAndReturn(title: "", content: "다음 날 순간", createdAt: afterMidnight))
        let draft = JournalDraftComposer.compose(on: day, records: store.records, existing: nil)
        #expect(draft.sourceRecordIDs == [original.id])
        let journal = try #require(store.saveJournal(on: day, title: draft.title, body: draft.body, sourceRecordIDs: draft.sourceRecordIDs))
        #expect(journal.dayKey == "2026-10-01")
        #expect(store.uncollectedMoments(on: day).isEmpty)
        let refreshedDay = JournalDay(date: afterMidnight, calendar: calendar)
        #expect(refreshedDay.key == "2026-10-02")
        #expect(store.uncollectedMoments(on: refreshedDay).map(\.id) == [next.id])
        #expect(store.journal(on: refreshedDay) == nil)
    }

    @Test("다음 자정은 DST 전환일에도 실제 날짜 경계를 따른다", arguments: [
        ["2026-03-08", "23"], ["2026-11-01", "25"]
    ])
    func nextBoundaryRespectsDaylightSaving(values: [String]) throws {
        let calendar = try calendar("America/Los_Angeles")
        let day = JournalDay(date: try date(values[0], in: calendar), calendar: calendar)
        let hours = try #require(Int(values[1]))
        #expect(day.nextBoundary.timeIntervalSince(day.date) == Double(hours * 3_600))
        #expect(!day.contains(day.nextBoundary))
        #expect(day.contains(day.nextBoundary.addingTimeInterval(-0.001)))
    }
}
