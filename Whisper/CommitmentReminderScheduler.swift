//
//  CommitmentReminderScheduler.swift
//  Whisper
//

import Foundation
import UserNotifications

struct ScheduledCommitmentReminder: Sendable {
    let encounterID: UUID
    let requestIdentifier: String
    let date: Date
}

struct CommitmentNotificationState: Sendable {
    let pendingRequestIdentifiers: Set<String>
    let deliveredEncounterDates: [UUID: Date]
}

enum CommitmentReminderScheduleResult: Sendable {
    case scheduled([ScheduledCommitmentReminder])
    case authorizationUnavailable
}

enum CommitmentReminderApplicationResult: Sendable, Equatable {
    case scheduled
    case authorizationUnavailable
    case failed
}

enum CommitmentReminderSchedulerError: LocalizedError {
    case noAvailableSchedule

    var errorDescription: String? {
        switch self {
        case .noAvailableSchedule:
            "알림이 너무 많이 겹쳐 다음 리마인드 시간을 정하지 못했어요."
        }
    }
}

enum CommitmentReminderScheduler {
    static let showPreviewStorageKey = "whisper.commitment.showNotificationPreview"
    static let allowedStartHourStorageKey = "whisper.commitment.allowedStartHour"
    static let allowedEndHourStorageKey = "whisper.commitment.allowedEndHour"

    private static let defaultAllowedStartHour = 9
    private static let defaultAllowedEndHour = 21
    private static let maximumReminderDatesPerPlan = 2
    private static let maximumCommitmentNotificationsPerDay = 1
    private static let maximumPendingCommitmentNotifications = 48
    private static let requestPrefix = "whisper.commitment."

    static func adjustedToAllowedReminderHours(_ date: Date) -> Date {
        adjustedToAllowedHours(date, calendar: .current)
    }

    static func schedule(
        _ plan: CommitmentReminderPlan
    ) async throws -> CommitmentReminderScheduleResult {
        let center = UNUserNotificationCenter.current()
        guard try await ensureAuthorization(using: center) else {
            await cancel(commitmentIDs: [plan.id])
            return .authorizationUnavailable
        }

        await cancel(commitmentIDs: [plan.id])

        let pendingRequests = await center.pendingNotificationRequests()
        let dates = schedulableDates(
            from: Array(plan.reminderDates.prefix(maximumReminderDatesPerPlan)),
            pendingRequests: pendingRequests
        )
        guard !dates.isEmpty else {
            throw CommitmentReminderSchedulerError.noAvailableSchedule
        }

        let showPreview = UserDefaults.standard.bool(forKey: showPreviewStorageKey)
        let calendar = Calendar.current
        var scheduled: [ScheduledCommitmentReminder] = []

        do {
            for (index, reminderDate) in dates.enumerated() {
                let encounterID = UUID()
                let identifier = requestIdentifier(commitmentID: plan.id, index: index)
                let dateComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: reminderDate
                )

                let content = UNMutableNotificationContent()
                content.title = "과거의 불꽃"
                content.body = showPreview
                    ? "“\(String(plan.quote.prefix(90)))” 그 마음은 지금도 남아 있나요?"
                    : "기억해 둔 마음을 다시 만나볼까요?"
                content.sound = .default
                content.threadIdentifier = "whisper.commitments"
                content.userInfo = [
                    "recordID": plan.sourceRecordID.uuidString,
                    "commitmentID": plan.id.uuidString,
                    "encounterID": encounterID.uuidString
                ]

                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(
                        dateMatching: dateComponents,
                        repeats: false
                    )
                )
                try await center.add(request)
                scheduled.append(
                    ScheduledCommitmentReminder(
                        encounterID: encounterID,
                        requestIdentifier: identifier,
                        date: reminderDate
                    )
                )
            }
        } catch {
            await cancel(requestIdentifiers: scheduled.map(\.requestIdentifier))
            throw error
        }

        return .scheduled(scheduled)
    }

    static func cancel(commitmentIDs: [UUID]) async {
        let identifiers = commitmentIDs.flatMap { commitmentID in
            (0..<3).map {
                requestIdentifier(commitmentID: commitmentID, index: $0)
            }
        }
        await cancel(requestIdentifiers: identifiers)
    }

    static func cancel(requestIdentifiers: [String]) async {
        guard !requestIdentifiers.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: requestIdentifiers)
    }

    static func currentNotificationState() async -> CommitmentNotificationState {
        let center = UNUserNotificationCenter.current()
        async let pending = center.pendingNotificationRequests()
        async let delivered = center.deliveredNotifications()
        let (pendingRequests, deliveredNotifications) = await (pending, delivered)

        let pendingIdentifiers = Set(
            pendingRequests
                .filter { $0.identifier.hasPrefix(requestPrefix) }
                .map(\.identifier)
        )
        let deliveredDates = deliveredNotifications.reduce(into: [UUID: Date]()) {
            result,
            notification in
            guard notification.request.identifier.hasPrefix(requestPrefix),
                  let value = notification.request.content.userInfo["encounterID"] as? String,
                  let encounterID = UUID(uuidString: value)
            else {
                return
            }
            result[encounterID] = notification.date
        }

        return CommitmentNotificationState(
            pendingRequestIdentifiers: pendingIdentifiers,
            deliveredEncounterDates: deliveredDates
        )
    }

    private static func schedulableDates(
        from proposedDates: [Date],
        pendingRequests: [UNNotificationRequest]
    ) -> [Date] {
        let commitmentRequests = pendingRequests.filter {
            $0.identifier.hasPrefix(requestPrefix)
        }
        let availableCount = max(
            0,
            maximumPendingCommitmentNotifications - commitmentRequests.count
        )
        guard availableCount > 0 else { return [] }

        var occupiedDates = commitmentRequests.compactMap(notificationDate)
        var result: [Date] = []

        for proposedDate in proposedDates.prefix(availableCount) {
            guard let availableDate = nextAvailableDate(
                startingAt: proposedDate,
                occupiedDates: occupiedDates
            ) else {
                continue
            }
            result.append(availableDate)
            occupiedDates.append(availableDate)
        }

        return result
    }

    private static func nextAvailableDate(
        startingAt proposedDate: Date,
        occupiedDates: [Date]
    ) -> Date? {
        let calendar = Calendar.current
        var candidate = adjustedToAllowedHours(proposedDate, calendar: calendar)

        for _ in 0..<90 {
            let occupiedCount = occupiedDates.filter {
                calendar.isDate($0, inSameDayAs: candidate)
            }.count
            if occupiedCount < maximumCommitmentNotificationsPerDay {
                return candidate
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: candidate),
                  let dayStart = calendar.date(
                    bySettingHour: allowedStartHour,
                    minute: 0,
                    second: 0,
                    of: nextDay
                  )
            else {
                return nil
            }
            candidate = dayStart
        }

        return nil
    }

    private static func adjustedToAllowedHours(
        _ date: Date,
        calendar: Calendar
    ) -> Date {
        let hour = calendar.component(.hour, from: date)
        if hour < allowedStartHour {
            return calendar.date(
                bySettingHour: allowedStartHour,
                minute: 0,
                second: 0,
                of: date
            ) ?? date
        }
        if hour >= allowedEndHour {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            return calendar.date(
                bySettingHour: allowedStartHour,
                minute: 0,
                second: 0,
                of: nextDay
            ) ?? nextDay
        }
        return date
    }

    private static var allowedStartHour: Int {
        storedHour(
            forKey: allowedStartHourStorageKey,
            defaultValue: defaultAllowedStartHour,
            validRange: 0...22
        )
    }

    private static var allowedEndHour: Int {
        let value = storedHour(
            forKey: allowedEndHourStorageKey,
            defaultValue: defaultAllowedEndHour,
            validRange: 1...23
        )
        return max(value, allowedStartHour + 1)
    }

    private static func storedHour(
        forKey key: String,
        defaultValue: Int,
        validRange: ClosedRange<Int>
    ) -> Int {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        let value = UserDefaults.standard.integer(forKey: key)
        return validRange.contains(value) ? value : defaultValue
    }

    nonisolated private static func notificationDate(_ request: UNNotificationRequest) -> Date? {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            return nil
        }
        return trigger.nextTriggerDate()
    }

    private static func ensureAuthorization(
        using center: UNUserNotificationCenter
    ) async throws -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound])
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static func requestIdentifier(commitmentID: UUID, index: Int) -> String {
        "\(requestPrefix)\(commitmentID.uuidString).\(index)"
    }
}

@MainActor
enum CommitmentReminderCoordinator {
    static func schedule(
        _ plan: CommitmentReminderPlan,
        in recordStore: RecordStore
    ) async -> CommitmentReminderApplicationResult {
        do {
            switch try await CommitmentReminderScheduler.schedule(plan) {
            case .authorizationUnavailable:
                _ = recordStore.clearScheduledEncounters(commitmentID: plan.id)
                return .authorizationUnavailable
            case .scheduled(let reminders):
                guard recordStore.replaceScheduledEncounters(
                    commitmentID: plan.id,
                    reminders: reminders
                ) else {
                    await CommitmentReminderScheduler.cancel(
                        requestIdentifiers: reminders.map(\.requestIdentifier)
                    )
                    _ = recordStore.clearScheduledEncounters(commitmentID: plan.id)
                    return .failed
                }
                return .scheduled
            }
        } catch {
            _ = recordStore.clearScheduledEncounters(commitmentID: plan.id)
            return .failed
        }
    }

    static func synchronize(with recordStore: RecordStore) async {
        let state = await CommitmentReminderScheduler.currentNotificationState()
        _ = recordStore.reconcileReminderNotifications(with: state)
    }
}
