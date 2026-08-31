//
//  CommitmentReminderPolicy.swift
//  Whisper
//

import Foundation

nonisolated enum CommitmentTimeSensitivity: String, Codable, CaseIterable, Sendable {
    case unspecified
    case immediate
    case soon
    case thisWeek
    case flexible
}

nonisolated enum CommitmentActionability: String, Codable, CaseIterable, Sendable {
    case unspecified
    case concrete
    case directional
    case attitude
}

nonisolated enum CommitmentEffort: String, Codable, CaseIterable, Sendable {
    case unspecified
    case light
    case moderate
    case heavy
}

nonisolated enum CommitmentCadence: String, Codable, CaseIterable, Sendable {
    case unspecified
    case oneOff
    case repeating
    case ongoing
}

nonisolated enum CommitmentPreferredPeriod: String, Codable, CaseIterable, Sendable {
    case unspecified
    case morning
    case daytime
    case evening
}

nonisolated struct CommitmentReminderProfile: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let timeSensitivity: CommitmentTimeSensitivity
    let actionability: CommitmentActionability
    let effort: CommitmentEffort
    let cadence: CommitmentCadence
    let preferredPeriod: CommitmentPreferredPeriod

    init(
        version: Int = currentVersion,
        timeSensitivity: CommitmentTimeSensitivity = .unspecified,
        actionability: CommitmentActionability = .unspecified,
        effort: CommitmentEffort = .unspecified,
        cadence: CommitmentCadence = .unspecified,
        preferredPeriod: CommitmentPreferredPeriod = .unspecified
    ) {
        self.version = version
        self.timeSensitivity = timeSensitivity
        self.actionability = actionability
        self.effort = effort
        self.cadence = cadence
        self.preferredPeriod = preferredPeriod
    }

    static let fallback = CommitmentReminderProfile()
}

enum CommitmentReminderPolicyEvent: Sendable {
    case remembered
    case continued
    case kept
    case recovery
}

struct ReminderBehaviorSummary: Sendable {
    let consecutiveUnopenedCount: Int
    let notificationsLast7Days: Int
    let lastReaction: ReminderEncounterReaction?
    let preferredOpenHour: Int?
    let lastEncounteredAt: Date?

    static let empty = ReminderBehaviorSummary(
        consecutiveUnopenedCount: 0,
        notificationsLast7Days: 0,
        lastReaction: nil,
        preferredOpenHour: nil,
        lastEncounteredAt: nil
    )
}

enum CommitmentReminderPolicy {
    static func nextReminderDate(
        profile: CommitmentReminderProfile,
        behavior: ReminderBehaviorSummary,
        event: CommitmentReminderPolicyEvent,
        now: Date,
        calendar: Calendar = .current
    ) -> Date {
        var intervalHours = baseIntervalHours(for: profile.timeSensitivity)
        intervalHours *= eventMultiplier(event)
        intervalHours *= actionabilityMultiplier(profile.actionability)
        intervalHours *= effortMultiplier(profile.effort)
        intervalHours *= cadenceMultiplier(profile.cadence)
        intervalHours *= unopenedMultiplier(behavior.consecutiveUnopenedCount)
        intervalHours *= recentVolumeMultiplier(behavior.notificationsLast7Days)

        let boundedHours = min(2_160, max(6, Int(intervalHours.rounded())))
        let earliest = now.addingTimeInterval(TimeInterval(boundedHours * 60 * 60))
        return alignedDate(
            earliest,
            profile: profile,
            behavior: behavior,
            calendar: calendar
        )
    }

    private static func baseIntervalHours(
        for sensitivity: CommitmentTimeSensitivity
    ) -> Double {
        switch sensitivity {
        case .immediate: 6
        case .soon: 24
        case .thisWeek: 72
        case .flexible: 168
        case .unspecified: 72
        }
    }

    private static func eventMultiplier(_ event: CommitmentReminderPolicyEvent) -> Double {
        switch event {
        case .remembered: 1
        case .continued: 0.75
        case .kept: 1.25
        case .recovery: 1
        }
    }

    private static func actionabilityMultiplier(
        _ actionability: CommitmentActionability
    ) -> Double {
        switch actionability {
        case .concrete: 0.75
        case .directional: 1
        case .attitude: 1.5
        case .unspecified: 1
        }
    }

    private static func effortMultiplier(_ effort: CommitmentEffort) -> Double {
        switch effort {
        case .light: 0.75
        case .moderate: 1
        case .heavy: 1.5
        case .unspecified: 1
        }
    }

    private static func cadenceMultiplier(_ cadence: CommitmentCadence) -> Double {
        switch cadence {
        case .oneOff: 1
        case .repeating: 0.8
        case .ongoing: 1.2
        case .unspecified: 1
        }
    }

    private static func unopenedMultiplier(_ count: Int) -> Double {
        switch max(0, count) {
        case 0: 1
        case 1: 1.75
        case 2: 2.5
        default: 4
        }
    }

    private static func recentVolumeMultiplier(_ count: Int) -> Double {
        switch max(0, count) {
        case 0...1: 1
        case 2...3: 1.35
        default: 1.75
        }
    }

    private static func alignedDate(
        _ date: Date,
        profile: CommitmentReminderProfile,
        behavior: ReminderBehaviorSummary,
        calendar: Calendar
    ) -> Date {
        let preferredHour = behavior.preferredOpenHour
            ?? preferredHour(for: profile.preferredPeriod)
        guard let preferredHour,
              let aligned = calendar.date(
                  bySettingHour: preferredHour,
                  minute: 0,
                  second: 0,
                  of: date
              )
        else {
            return date
        }

        if aligned >= date {
            return aligned
        }
        return calendar.date(byAdding: .day, value: 1, to: aligned) ?? date
    }

    private static func preferredHour(
        for period: CommitmentPreferredPeriod
    ) -> Int? {
        switch period {
        case .morning: 9
        case .daytime: 14
        case .evening: 19
        case .unspecified: nil
        }
    }
}
