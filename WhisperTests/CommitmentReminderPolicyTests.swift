//
//  CommitmentReminderPolicyTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@Suite("리마인드 시간 정책", .serialized)
struct CommitmentReminderPolicyTests {
    private let calendar = Calendar.current

    @Test("허용 시간 전이면 같은 날 오전 9시로 조정한다")
    func adjustsEarlyReminderToMorning() throws {
        let date = try makeDate(year: 2026, month: 8, day: 28, hour: 7, minute: 30)

        let adjusted = withDefaultAllowedHours {
            CommitmentReminderScheduler.adjustedToAllowedReminderHours(date)
        }

        #expect(calendar.component(.day, from: adjusted) == 28)
        #expect(calendar.component(.hour, from: adjusted) == 9)
        #expect(calendar.component(.minute, from: adjusted) == 0)
    }

    @Test("허용 시간이 끝난 뒤면 다음 날 오전 9시로 조정한다")
    func adjustsLateReminderToNextMorning() throws {
        let date = try makeDate(year: 2026, month: 8, day: 28, hour: 21, minute: 15)

        let adjusted = withDefaultAllowedHours {
            CommitmentReminderScheduler.adjustedToAllowedReminderHours(date)
        }

        #expect(calendar.component(.day, from: adjusted) == 29)
        #expect(calendar.component(.hour, from: adjusted) == 9)
        #expect(calendar.component(.minute, from: adjusted) == 0)
    }

    @Test("허용 시간 안의 날짜는 바꾸지 않는다")
    func preservesAllowedReminderDate() throws {
        let date = try makeDate(year: 2026, month: 8, day: 28, hour: 14, minute: 25)

        let adjusted = withDefaultAllowedHours {
            CommitmentReminderScheduler.adjustedToAllowedReminderHours(date)
        }

        #expect(adjusted == date)
    }

    @Test("교체 알림은 만남마다 고유한 식별자를 만든다")
    func createsUniqueReplacementIdentifiers() {
        let commitmentID = UUID()
        let first = CommitmentReminderScheduler.requestIdentifier(
            commitmentID: commitmentID,
            encounterID: UUID()
        )
        let second = CommitmentReminderScheduler.requestIdentifier(
            commitmentID: commitmentID,
            encounterID: UUID()
        )

        #expect(first != second)
        #expect(first.hasPrefix("whisper.commitment.\(commitmentID.uuidString)."))
        #expect(second.hasPrefix("whisper.commitment.\(commitmentID.uuidString)."))
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }

    private func withDefaultAllowedHours<T>(_ operation: () -> T) -> T {
        let defaults = UserDefaults.standard
        let startKey = CommitmentReminderScheduler.allowedStartHourStorageKey
        let endKey = CommitmentReminderScheduler.allowedEndHourStorageKey
        let previousStart = defaults.object(forKey: startKey)
        let previousEnd = defaults.object(forKey: endKey)

        defaults.removeObject(forKey: startKey)
        defaults.removeObject(forKey: endKey)
        defer {
            restore(previousStart, forKey: startKey, in: defaults)
            restore(previousEnd, forKey: endKey, in: defaults)
        }

        return operation()
    }

    private func restore(_ value: Any?, forKey key: String, in defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
