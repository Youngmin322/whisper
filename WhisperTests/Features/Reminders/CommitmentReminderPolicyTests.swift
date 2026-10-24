//
//  CommitmentReminderPolicyTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@Suite("리마인드 시간 정책", .serialized)
struct CommitmentReminderPolicyTests {
    @Test("같은 의미 프로필과 행동에는 항상 같은 다음 시각을 계산한다")
    func deterministicPolicyProducesSameDate() throws {
        let now = try makeDate(year: 2026, month: 8, day: 31, hour: 10, minute: 0)
        let profile = CommitmentReminderProfile(
            timeSensitivity: .immediate,
            actionability: .concrete,
            effort: .light,
            cadence: .oneOff
        )

        let first = CommitmentReminderPolicy.nextReminderDate(
            profile: profile,
            behavior: .empty,
            event: .remembered,
            now: now,
            calendar: calendar
        )
        let second = CommitmentReminderPolicy.nextReminderDate(
            profile: profile,
            behavior: .empty,
            event: .remembered,
            now: now,
            calendar: calendar
        )

        #expect(first == second)
        #expect(first == now.addingTimeInterval(6 * 60 * 60))
    }

    @Test("열지 않은 알림이 이어질수록 다음 알림 간격을 늘린다")
    func backsOffAfterUnopenedReminders() throws {
        let now = try makeDate(year: 2026, month: 8, day: 31, hour: 10, minute: 0)
        let profile = CommitmentReminderProfile(timeSensitivity: .soon)
        let normal = CommitmentReminderPolicy.nextReminderDate(
            profile: profile,
            behavior: .empty,
            event: .remembered,
            now: now,
            calendar: calendar
        )
        let backedOff = CommitmentReminderPolicy.nextReminderDate(
            profile: profile,
            behavior: ReminderBehaviorSummary(
                consecutiveUnopenedCount: 2,
                notificationsLast7Days: 2,
                lastReaction: nil,
                preferredOpenHour: nil,
                lastEncounteredAt: nil
            ),
            event: .remembered,
            now: now,
            calendar: calendar
        )

        #expect(backedOff > normal)
    }

    @Test("사용자가 주로 여는 시간이 있으면 의미상 시간대보다 우선한다")
    func learnedOpenHourWinsOverSemanticPeriod() throws {
        let now = try makeDate(year: 2026, month: 8, day: 31, hour: 10, minute: 0)
        let date = CommitmentReminderPolicy.nextReminderDate(
            profile: CommitmentReminderProfile(
                timeSensitivity: .soon,
                preferredPeriod: .morning
            ),
            behavior: ReminderBehaviorSummary(
                consecutiveUnopenedCount: 0,
                notificationsLast7Days: 0,
                lastReaction: .keep,
                preferredOpenHour: 19,
                lastEncounteredAt: nil
            ),
            event: .remembered,
            now: now,
            calendar: calendar
        )

        #expect(calendar.component(.hour, from: date) == 19)
    }

    @Test("저장소가 모르는 앱 알림 식별자만 고아 상태로 분류한다")
    func detectsOrphanedNotificationRequests() {
        let trackedPending = "whisper.commitment.tracked.pending"
        let trackedDelivered = "whisper.commitment.tracked.delivered"
        let orphanedPending = "whisper.commitment.orphaned.pending"
        let orphanedDelivered = "whisper.commitment.orphaned.delivered"
        let state = CommitmentNotificationState(
            pendingRequestIdentifiers: [trackedPending, orphanedPending],
            deliveredRequestIdentifiers: [trackedDelivered, orphanedDelivered],
            deliveredEncounterDates: [:]
        )

        #expect(
            state.orphanedRequestIdentifiers(
                trackedRequestIdentifiers: [trackedPending, trackedDelivered]
            ) == [orphanedPending, orphanedDelivered]
        )
    }

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
