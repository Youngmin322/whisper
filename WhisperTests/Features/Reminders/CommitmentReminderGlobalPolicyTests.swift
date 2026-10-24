//
//  CommitmentReminderGlobalPolicyTests.swift
//  WhisperTests
//

import Foundation
import Testing
@testable import Whisper

@Suite("결심 리마인드 전역 배치 정책")
struct CommitmentReminderGlobalPolicyTests {
    private let seoulTimeZone = TimeZone(identifier: "Asia/Seoul")!

    @Test("오늘 이미 알림을 한 번 사용했다면 다음 빈 날짜로 미룬다")
    func avoidsDayThatWasAlreadyUsed() throws {
        let calendar = makeCalendar()
        let now = try makeDate(day: 31, hour: 13, calendar: calendar)
        let proposedDate = try makeDate(day: 31, hour: 15, calendar: calendar)
        let occupiedDate = try makeDate(day: 31, hour: 10, calendar: calendar)
        let commitmentID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        let allocation = CommitmentReminderGlobalPolicy.allocate(
            inputs: [
                makeInput(
                    id: commitmentID,
                    reminderDates: [proposedDate],
                    createdAt: try makeDate(day: 20, hour: 9, calendar: calendar)
                )
            ],
            occupiedDates: [occupiedDate],
            policy: makePolicy(now: now, calendar: calendar)
        )

        let assignment = try #require(allocation.assignments.first)
        let expectedDate = try makeDate(day: 1, month: 9, hour: 9, calendar: calendar)
        #expect(allocation.assignments.count == 1)
        #expect(assignment.commitmentID == commitmentID)
        #expect(assignment.proposedDate == proposedDate)
        #expect(assignment.scheduledDate == expectedDate)
        #expect(allocation.unassignedCommitmentIDs.isEmpty)
    }

    @Test("각 결심의 첫 알림을 모두 배치한 뒤 두 번째 알림을 배치한다")
    func allocatesOneReminderPerCommitmentBeforeSecondRound() throws {
        let calendar = makeCalendar()
        let now = try makeDate(day: 31, hour: 13, calendar: calendar)
        let firstProposal = try makeDate(day: 31, hour: 15, calendar: calendar)
        let secondProposal = try makeDate(day: 31, hour: 17, calendar: calendar)
        let neverEncounteredID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let leastRecentID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let mostRecentID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

        let allocation = CommitmentReminderGlobalPolicy.allocate(
            inputs: [
                makeInput(
                    id: mostRecentID,
                    reminderDates: [firstProposal, secondProposal],
                    lastEncounteredAt: try makeDate(day: 30, hour: 9, calendar: calendar),
                    createdAt: try makeDate(day: 12, hour: 9, calendar: calendar)
                ),
                makeInput(
                    id: neverEncounteredID,
                    reminderDates: [firstProposal, secondProposal],
                    lastEncounteredAt: nil,
                    createdAt: try makeDate(day: 10, hour: 9, calendar: calendar)
                ),
                makeInput(
                    id: leastRecentID,
                    reminderDates: [firstProposal, secondProposal],
                    lastEncounteredAt: try makeDate(day: 21, hour: 9, calendar: calendar),
                    createdAt: try makeDate(day: 11, hour: 9, calendar: calendar)
                )
            ],
            occupiedDates: [],
            policy: makePolicy(now: now, calendar: calendar)
        )

        let orderedAssignments = allocation.assignments.sorted {
            $0.scheduledDate < $1.scheduledDate
        }

        #expect(orderedAssignments.map(\.commitmentID) == [
            neverEncounteredID,
            leastRecentID,
            mostRecentID,
            neverEncounteredID,
            leastRecentID,
            mostRecentID
        ])
        #expect(orderedAssignments.map(\.occurrenceIndex) == [0, 0, 0, 1, 1, 1])
        #expect(Set(orderedAssignments.map { calendar.startOfDay(for: $0.scheduledDate) }).count == 6)
        #expect(allocation.unassignedCommitmentIDs.isEmpty)
    }

    @Test("입력 순서가 달라도 공정 배치 결과는 같다")
    func allocationDoesNotDependOnInputOrder() throws {
        let calendar = makeCalendar()
        let now = try makeDate(day: 31, hour: 13, calendar: calendar)
        let proposedDate = try makeDate(day: 31, hour: 15, calendar: calendar)
        let ids = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        ]
        let inputs = try ids.enumerated().map { index, id in
            makeInput(
                id: id,
                reminderDates: [proposedDate],
                lastEncounteredAt: nil,
                createdAt: try makeDate(day: 10 + index, hour: 9, calendar: calendar)
            )
        }
        let policy = makePolicy(now: now, calendar: calendar)

        let forward = CommitmentReminderGlobalPolicy.allocate(
            inputs: inputs,
            occupiedDates: [],
            policy: policy
        )
        let reversed = CommitmentReminderGlobalPolicy.allocate(
            inputs: Array(inputs.reversed()),
            occupiedDates: [],
            policy: policy
        )

        #expect(scheduleSignature(forward) == scheduleSignature(reversed))
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoulTimeZone
        return calendar
    }

    private func makePolicy(
        now: Date,
        calendar: Calendar
    ) -> CommitmentReminderAllocationPolicy {
        CommitmentReminderAllocationPolicy(
            now: now,
            calendar: calendar,
            allowedStartHour: 9,
            allowedEndHour: 21,
            maximumPerDay: 1,
            maximumTotal: 48,
            horizonDays: 90
        )
    }

    private func makeInput(
        id: UUID,
        reminderDates: [Date],
        lastEncounteredAt: Date? = nil,
        createdAt: Date
    ) -> CommitmentReminderAllocationInput {
        CommitmentReminderAllocationInput(
            plan: CommitmentReminderPlan(
                id: id,
                sourceRecordID: UUID(),
                name: "테스트 결심",
                quote: "이 마음을 기억하자",
                reminderDates: reminderDates
            ),
            lastEncounteredAt: lastEncounteredAt,
            createdAt: createdAt
        )
    }

    private func makeDate(
        day: Int,
        month: Int = 8,
        hour: Int,
        calendar: Calendar
    ) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(
                    timeZone: seoulTimeZone,
                    year: 2026,
                    month: month,
                    day: day,
                    hour: hour
                )
            )
        )
    }

    private func scheduleSignature(
        _ allocation: CommitmentReminderAllocation
    ) -> [String] {
        allocation.assignments
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .map {
                "\($0.commitmentID.uuidString)|\($0.occurrenceIndex)|\($0.scheduledDate.timeIntervalSince1970)"
            }
    }
}
