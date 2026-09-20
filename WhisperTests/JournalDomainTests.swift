//
//  JournalDomainTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@MainActor
@Suite("하루 일기 도메인", .serialized)
struct JournalDomainTests {
    @Test("순간을 시간 순서대로 묶어 하루 초안을 만든다")
    func composesMomentsChronologically() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let calendar = fixedCalendar
        let day = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 12))
        )
        let evening = try #require(calendar.date(byAdding: .hour, value: 6, to: day))
        let morning = try #require(calendar.date(byAdding: .hour, value: -4, to: day))

        let eveningRecord = try #require(
            store.addAndReturn(title: "저녁", content: "친구가 보내준 노래를 오래 들었다.", createdAt: evening)
        )
        let morningRecord = try #require(
            store.addAndReturn(title: "아침", content: "바람이 좋아서 한 정거장 먼저 내렸다.", createdAt: morning)
        )

        let draft = store.journalDraft(on: day, calendar: calendar)

        #expect(draft.title == "2개의 순간이 이어진 하루")
        #expect(draft.body == "바람이 좋아서 한 정거장 먼저 내렸다.\n\n친구가 보내준 노래를 오래 들었다.")
        #expect(draft.sourceRecordIDs == [morningRecord.id, eveningRecord.id])
    }

    @Test("같은 날짜의 완성 일기는 한 건만 저장하고 다시 수정한다")
    func upsertsOneJournalPerDay() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let calendar = fixedCalendar
        let day = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 20))
        )
        let moment = try #require(
            store.addAndReturn(title: "순간", content: "오늘의 장면", createdAt: day)
        )

        let first = try #require(
            store.saveJournal(
                on: day,
                title: "처음 제목",
                body: "처음 본문",
                reflection: "천천히 가도 괜찮다.",
                emotion: "차분함",
                sourceRecordIDs: [moment.id],
                calendar: calendar,
                now: day
            )
        )
        let updated = try #require(
            store.saveJournal(
                on: day,
                title: "바뀐 제목",
                body: "바뀐 본문",
                reflection: "다시 시작할 수 있다.",
                emotion: "가벼움",
                sourceRecordIDs: [moment.id],
                calendar: calendar,
                now: day.addingTimeInterval(60)
            )
        )

        #expect(first.id == updated.id)
        #expect(store.journals.count == 1)
        #expect(updated.title == "바뀐 제목")
        #expect(updated.reflection == "다시 시작할 수 있다.")
        #expect(updated.sourceRecordIDs == [moment.id])
    }

    @Test("자정이 지나면 전날 순간을 새 일기 초안에 섞지 않는다")
    func separatesMomentsAtLocalMidnight() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let calendar = fixedCalendar
        let previousDay = try #require(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 9,
                day: 16,
                hour: 23,
                minute: 59
            ))
        )
        let nextDay = try #require(
            calendar.date(from: DateComponents(
                year: 2026,
                month: 9,
                day: 17,
                hour: 0,
                minute: 1
            ))
        )

        _ = store.addAndReturn(
            title: "어제",
            content: "자정 전의 순간",
            createdAt: previousDay
        )
        let todayMoment = try #require(
            store.addAndReturn(
                title: "오늘",
                content: "자정 뒤의 순간",
                createdAt: nextDay
            )
        )

        let draft = store.journalDraft(on: nextDay, calendar: calendar)

        #expect(draft.body == "자정 뒤의 순간")
        #expect(draft.sourceRecordIDs == [todayMoment.id])
        #expect(JournalDayKey.make(for: nextDay, calendar: calendar) == "2026-09-17")
    }

    @Test("순간이 없는 날은 비어 있는 안전한 초안을 만든다")
    func composesEmptyDraft() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let calendar = fixedCalendar
        let day = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 12))
        )

        let draft = store.journalDraft(on: day, calendar: calendar)

        #expect(draft.isEmpty)
        #expect(draft.title == "오늘의 일기")
        #expect(draft.body.isEmpty)
        #expect(draft.sourceRecordIDs.isEmpty)
    }

    @Test("완성하지 않은 날짜만 최근 순서로 다시 찾는다")
    func findsUnfinishedJournalDays() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let calendar = fixedCalendar
        let firstDay = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 9))
        )
        let secondDay = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 9))
        )
        let thirdDay = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 9))
        )

        let firstMoment = try #require(
            store.addAndReturn(title: "첫날", content: "첫날의 순간", createdAt: firstDay)
        )
        _ = store.addAndReturn(title: "둘째 날", content: "둘째 날의 순간", createdAt: secondDay)
        _ = store.addAndReturn(title: "셋째 날", content: "셋째 날의 순간", createdAt: thirdDay)

        _ = try #require(
            store.saveJournal(
                on: firstDay,
                title: "완성한 첫날",
                body: "첫날의 순간",
                reflection: "",
                emotion: nil,
                sourceRecordIDs: [firstMoment.id],
                calendar: calendar,
                now: thirdDay
            )
        )

        let unfinishedDays = store.unfinishedJournalDays(calendar: calendar)

        #expect(unfinishedDays.map(\.date) == [
            calendar.startOfDay(for: thirdDay),
            calendar.startOfDay(for: secondDay)
        ])
        #expect(unfinishedDays.map(\.records.count) == [1, 1])
    }

    private var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}
