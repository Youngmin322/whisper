//
//  CommitmentReminderGlobalPolicy.swift
//  Whisper
//

import Foundation

struct CommitmentReminderAllocationInput: Sendable {
    let plan: CommitmentReminderPlan
    let lastEncounteredAt: Date?
    let createdAt: Date
}

struct CommitmentReminderAllocationPolicy: Sendable {
    let now: Date
    let calendar: Calendar
    let allowedStartHour: Int
    let allowedEndHour: Int
    let maximumPerDay: Int
    let maximumTotal: Int
    let horizonDays: Int
}

struct CommitmentReminderAssignment: Sendable, Equatable {
    let commitmentID: UUID
    let proposedDate: Date
    let scheduledDate: Date
    let occurrenceIndex: Int
}

struct CommitmentReminderAllocation: Sendable, Equatable {
    let assignments: [CommitmentReminderAssignment]
    let unassignedCommitmentIDs: Set<UUID>
}

enum CommitmentReminderGlobalPolicy {
    private struct Candidate {
        let input: CommitmentReminderAllocationInput
        let proposedDate: Date
        let occurrenceIndex: Int
    }

    /// Allocates every commitment's first reminder before considering any
    /// commitment's second reminder. Model-proposed dates are treated as the
    /// earliest eligible dates; the application owns the final delivery slot.
    static func allocate(
        inputs: [CommitmentReminderAllocationInput],
        occupiedDates: [Date],
        policy: CommitmentReminderAllocationPolicy
    ) -> CommitmentReminderAllocation {
        guard policy.maximumPerDay > 0,
              policy.maximumTotal > 0,
              policy.horizonDays >= 0,
              policy.allowedStartHour >= 0,
              policy.allowedEndHour > policy.allowedStartHour,
              policy.allowedEndHour <= 24
        else {
            return CommitmentReminderAllocation(
                assignments: [],
                unassignedCommitmentIDs: Set(inputs.map { $0.plan.id })
            )
        }

        let normalizedDates = Dictionary(uniqueKeysWithValues: inputs.map { input in
            let dates = Array(Set(input.plan.reminderDates).sorted().prefix(2))
            return (input.plan.id, dates)
        })
        let maximumOccurrenceCount = normalizedDates.values.map(\.count).max() ?? 0
        let occupiedFutureCount = occupiedDates.filter { $0 > policy.now }.count
        let availableCount = max(0, policy.maximumTotal - occupiedFutureCount)

        var allOccupiedDates = occupiedDates
        var assignments: [CommitmentReminderAssignment] = []
        var unassignedIDs = Set<UUID>()

        for occurrenceIndex in 0..<maximumOccurrenceCount {
            let candidates = inputs.compactMap { input -> Candidate? in
                guard let dates = normalizedDates[input.plan.id],
                      dates.indices.contains(occurrenceIndex)
                else {
                    return nil
                }
                return Candidate(
                    input: input,
                    proposedDate: dates[occurrenceIndex],
                    occurrenceIndex: occurrenceIndex
                )
            }
            .sorted { lhs, rhs in
                candidateIsOrderedBefore(lhs, rhs, policy: policy)
            }

            for candidate in candidates {
                guard assignments.count < availableCount,
                      let scheduledDate = nextAvailableDate(
                        startingAt: candidate.proposedDate,
                        occupiedDates: allOccupiedDates,
                        policy: policy
                      )
                else {
                    unassignedIDs.insert(candidate.input.plan.id)
                    continue
                }

                assignments.append(
                    CommitmentReminderAssignment(
                        commitmentID: candidate.input.plan.id,
                        proposedDate: candidate.proposedDate,
                        scheduledDate: scheduledDate,
                        occurrenceIndex: candidate.occurrenceIndex
                    )
                )
                allOccupiedDates.append(scheduledDate)
            }
        }

        return CommitmentReminderAllocation(
            assignments: assignments,
            unassignedCommitmentIDs: unassignedIDs
        )
    }

    private static func candidateIsOrderedBefore(
        _ lhs: Candidate,
        _ rhs: Candidate,
        policy: CommitmentReminderAllocationPolicy
    ) -> Bool {
        let lhsDate = adjustedToAllowedHours(lhs.proposedDate, policy: policy)
        let rhsDate = adjustedToAllowedHours(rhs.proposedDate, policy: policy)
        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        switch (lhs.input.lastEncounteredAt, rhs.input.lastEncounteredAt) {
        case (nil, .some):
            return true
        case (.some, nil):
            return false
        case let (.some(lhsEncounter), .some(rhsEncounter)) where lhsEncounter != rhsEncounter:
            return lhsEncounter < rhsEncounter
        default:
            break
        }

        if lhs.input.createdAt != rhs.input.createdAt {
            return lhs.input.createdAt < rhs.input.createdAt
        }
        return lhs.input.plan.id.uuidString < rhs.input.plan.id.uuidString
    }

    private static func nextAvailableDate(
        startingAt proposedDate: Date,
        occupiedDates: [Date],
        policy: CommitmentReminderAllocationPolicy
    ) -> Date? {
        let calendar = policy.calendar
        let earliestDate = max(proposedDate, policy.now.addingTimeInterval(60))
        var candidate = adjustedToAllowedHours(earliestDate, policy: policy)
        let horizonEnd = calendar.date(
            byAdding: .day,
            value: policy.horizonDays,
            to: calendar.startOfDay(for: policy.now)
        ) ?? candidate

        while candidate < horizonEnd || calendar.isDate(candidate, inSameDayAs: horizonEnd) {
            let occupiedCount = occupiedDates.lazy.filter {
                calendar.isDate($0, inSameDayAs: candidate)
            }.count
            if occupiedCount < policy.maximumPerDay {
                return candidate
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: candidate),
                  let startOfWindow = calendar.date(
                    bySettingHour: policy.allowedStartHour,
                    minute: 0,
                    second: 0,
                    of: nextDay
                  )
            else {
                return nil
            }
            candidate = startOfWindow
        }
        return nil
    }

    private static func adjustedToAllowedHours(
        _ date: Date,
        policy: CommitmentReminderAllocationPolicy
    ) -> Date {
        let calendar = policy.calendar
        let hour = calendar.component(.hour, from: date)
        if hour < policy.allowedStartHour {
            return calendar.date(
                bySettingHour: policy.allowedStartHour,
                minute: 0,
                second: 0,
                of: date
            ) ?? date
        }
        if hour >= policy.allowedEndHour {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            return calendar.date(
                bySettingHour: policy.allowedStartHour,
                minute: 0,
                second: 0,
                of: nextDay
            ) ?? nextDay
        }
        return date
    }
}
