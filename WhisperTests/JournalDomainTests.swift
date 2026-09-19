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

    private var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60) ?? .current
        return calendar
    }
}
