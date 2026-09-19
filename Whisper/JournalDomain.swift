//
//  JournalDomain.swift
//  Whisper
//

import Foundation

enum JournalDayKey {
    static func make(
        for date: Date,
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

struct DailyJournalDraft: Equatable, Sendable {
    let date: Date
    let title: String
    let body: String
    let sourceRecordIDs: [UUID]

    var isEmpty: Bool {
        sourceRecordIDs.isEmpty
    }
}

enum DailyJournalComposer {
    static func compose(
        from records: [WhisperRecord],
        on date: Date,
        calendar: Calendar = .current
    ) -> DailyJournalDraft {
        let moments = records
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.createdAt < $1.createdAt
            }

        return DailyJournalDraft(
            date: calendar.startOfDay(for: date),
            title: title(for: moments),
            body: moments.map(\.content).joined(separator: "\n\n"),
            sourceRecordIDs: moments.map(\.id)
        )
    }

    private static func title(for moments: [WhisperRecord]) -> String {
        switch moments.count {
        case 0:
            "오늘의 일기"
        case 1:
            "마음에 남은 한 순간"
        default:
            "\(moments.count)개의 순간이 이어진 하루"
        }
    }
}
