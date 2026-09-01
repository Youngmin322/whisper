//
//  CommitmentReminderScheduler.swift
//  Whisper
//

import Foundation
import OSLog
import UserNotifications

enum WhisperNotificationSource: String, Sendable {
    case commitment
    case focus
}

enum WhisperNotificationDayKey {
    nonisolated static func make(
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

actor WhisperNotificationScheduleGate {
    static let shared = WhisperNotificationScheduleGate()

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
    }
}

struct ScheduledCommitmentReminder: Sendable {
    let encounterID: UUID
    let requestIdentifier: String
    let date: Date
}

struct CommitmentNotificationState: Sendable {
    let pendingRequestIdentifiers: Set<String>
    let deliveredRequestIdentifiers: Set<String>
    let deliveredEncounterDates: [UUID: Date]

    var managedRequestIdentifiers: Set<String> {
        pendingRequestIdentifiers.union(deliveredRequestIdentifiers)
    }

    func orphanedRequestIdentifiers(
        trackedRequestIdentifiers: Set<String>
    ) -> Set<String> {
        managedRequestIdentifiers.subtracting(trackedRequestIdentifiers)
    }
}

fileprivate struct CommitmentReminderReplacementToken: @unchecked Sendable {
    let previousRequestIdentifiers: Set<String>
    let previousPendingRequests: [UNNotificationRequest]
    let newRequestIdentifiers: [String]
}

fileprivate enum CommitmentReminderBatchScheduleResult: Sendable {
    case scheduled(
        remindersByCommitment: [UUID: [ScheduledCommitmentReminder]],
        replacementToken: CommitmentReminderReplacementToken
    )
    case authorizationUnavailable
}

enum CommitmentReminderApplicationResult: Sendable, Equatable {
    case scheduled
    case authorizationUnavailable
    case failed
}

#if DEBUG
enum CommitmentReminderDebugResult: Sendable, Equatable {
    case scheduled(Date)
    case noActiveCommitment
    case authorizationUnavailable
    case failed
}

fileprivate enum CommitmentReminderDebugScheduleResult: Sendable {
    case scheduled(ScheduledCommitmentReminder)
    case authorizationUnavailable
}
#endif

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
    nonisolated static let showPreviewStorageKey = "whisper.commitment.showNotificationPreview"
    static let allowedStartHourStorageKey = "whisper.commitment.allowedStartHour"
    static let allowedEndHourStorageKey = "whisper.commitment.allowedEndHour"

    private static let defaultAllowedStartHour = 9
    private static let defaultAllowedEndHour = 21
    private static let maximumCommitmentNotificationsPerDay = 1
    private static let maximumPendingCommitmentNotifications = 48
    private static let applicationRequestPrefix = "whisper."
    private static let requestPrefix = "whisper.commitment."
#if DEBUG
    static let debugRequestPrefix = "whisper.debug.commitment."
#endif

    static func adjustedToAllowedReminderHours(_ date: Date) -> Date {
        adjustedToAllowedHours(date, calendar: .current)
    }

    fileprivate static func allocationPolicy(
        at date: Date,
        calendar: Calendar = .current
    ) -> CommitmentReminderAllocationPolicy {
        CommitmentReminderAllocationPolicy(
            now: date,
            calendar: calendar,
            allowedStartHour: allowedStartHour,
            allowedEndHour: allowedEndHour,
            maximumPerDay: maximumCommitmentNotificationsPerDay,
            maximumTotal: maximumPendingCommitmentNotifications,
            horizonDays: 90
        )
    }

    fileprivate static func schedule(
        _ allocation: CommitmentReminderAllocation,
        inputs: [CommitmentReminderAllocationInput],
        replacingRequestIdentifiers: Set<String>
    ) async throws -> CommitmentReminderBatchScheduleResult {
        let center = UNUserNotificationCenter.current()
        if !allocation.assignments.isEmpty {
            guard try await ensureAuthorization(using: center) else {
                return .authorizationUnavailable
            }
        }

        let plansByID = inputs.reduce(into: [UUID: CommitmentReminderPlan]()) {
            result,
            input in
            result[input.plan.id] = input.plan
        }
        guard allocation.assignments.allSatisfy({ plansByID[$0.commitmentID] != nil }) else {
            throw CommitmentReminderSchedulerError.noAvailableSchedule
        }

        let previousPendingRequests = await center.pendingNotificationRequests()
            .filter { replacingRequestIdentifiers.contains($0.identifier) }
        center.removePendingNotificationRequests(
            withIdentifiers: Array(replacingRequestIdentifiers)
        )

        guard !allocation.assignments.isEmpty else {
            return .scheduled(
                remindersByCommitment: [:],
                replacementToken: CommitmentReminderReplacementToken(
                    previousRequestIdentifiers: replacingRequestIdentifiers,
                    previousPendingRequests: previousPendingRequests,
                    newRequestIdentifiers: []
                )
            )
        }

        let showPreview = UserDefaults.standard.bool(forKey: showPreviewStorageKey)
        let calendar = Calendar.current
        var remindersByCommitment: [UUID: [ScheduledCommitmentReminder]] = [:]
        var newRequestIdentifiers: [String] = []

        do {
            for assignment in allocation.assignments.sorted(by: {
                if $0.scheduledDate != $1.scheduledDate {
                    return $0.scheduledDate < $1.scheduledDate
                }
                if $0.occurrenceIndex != $1.occurrenceIndex {
                    return $0.occurrenceIndex < $1.occurrenceIndex
                }
                return $0.commitmentID.uuidString < $1.commitmentID.uuidString
            }) {
                guard let plan = plansByID[assignment.commitmentID] else { continue }
                let encounterID = UUID()
                let identifier = requestIdentifier(
                    commitmentID: plan.id,
                    encounterID: encounterID
                )
                let request = notificationRequest(
                    identifier: identifier,
                    encounterID: encounterID,
                    plan: plan,
                    date: assignment.scheduledDate,
                    showPreview: showPreview,
                    calendar: calendar
                )
                newRequestIdentifiers.append(identifier)
                try await center.add(request)
                remindersByCommitment[plan.id, default: []].append(
                    ScheduledCommitmentReminder(
                        encounterID: encounterID,
                        requestIdentifier: identifier,
                        date: assignment.scheduledDate
                    )
                )
            }
        } catch {
            await rollbackReplacement(
                previousPendingRequests: previousPendingRequests,
                newRequestIdentifiers: newRequestIdentifiers,
                using: center
            )
            throw error
        }

        return .scheduled(
            remindersByCommitment: remindersByCommitment,
            replacementToken: CommitmentReminderReplacementToken(
                previousRequestIdentifiers: replacingRequestIdentifiers,
                previousPendingRequests: previousPendingRequests,
                newRequestIdentifiers: newRequestIdentifiers
            )
        )
    }

    fileprivate static func rollback(
        _ token: CommitmentReminderReplacementToken
    ) async {
        await rollbackReplacement(
            previousPendingRequests: token.previousPendingRequests,
            newRequestIdentifiers: token.newRequestIdentifiers,
            using: UNUserNotificationCenter.current()
        )
    }

    fileprivate static func commit(
        _ token: CommitmentReminderReplacementToken
    ) {
        guard !token.previousRequestIdentifiers.isEmpty else { return }
        let identifiers = Array(token.previousRequestIdentifiers)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    fileprivate static func cancel(commitmentIDs: [UUID]) async {
        guard !commitmentIDs.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        async let pending = center.pendingNotificationRequests()
        async let delivered = center.deliveredNotifications()
        var prefixes = commitmentIDs.map(commitmentRequestPrefix)
#if DEBUG
        prefixes.append(contentsOf: commitmentIDs.map(debugCommitmentRequestPrefix))
#endif
        let (pendingRequests, deliveredNotifications) = await (pending, delivered)
        let identifiers = pendingRequests.map(\.identifier) + deliveredNotifications.map {
            $0.request.identifier
        }
        await cancel(
            requestIdentifiers: identifiers.filter { identifier in
                prefixes.contains { identifier.hasPrefix($0) }
            }
        )
    }

    fileprivate static func cancel(requestIdentifiers: [String]) async {
        guard !requestIdentifiers.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: requestIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: requestIdentifiers)
    }

    private static func rollbackReplacement(
        previousPendingRequests: [UNNotificationRequest],
        newRequestIdentifiers: [String],
        using center: UNUserNotificationCenter
    ) async {
        if !newRequestIdentifiers.isEmpty {
            center.removePendingNotificationRequests(
                withIdentifiers: newRequestIdentifiers
            )
            center.removeDeliveredNotifications(
                withIdentifiers: newRequestIdentifiers
            )
        }

        for request in previousPendingRequests {
            do {
                try await center.add(request)
            } catch {
                let nsError = error as NSError
                WhisperDiagnostics.reminderLogger.error(
                    "Previous reminder restore failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
                )
            }
        }
    }

    static func currentNotificationState() async -> CommitmentNotificationState {
        let center = UNUserNotificationCenter.current()
        async let pending = center.pendingNotificationRequests()
        async let delivered = center.deliveredNotifications()
        let (pendingRequests, deliveredNotifications) = await (pending, delivered)

        let pendingIdentifiers = Set(
            pendingRequests
                .filter { isManagedReminderIdentifier($0.identifier) }
                .map(\.identifier)
        )
        let deliveredIdentifiers = Set(
            deliveredNotifications
                .map(\.request.identifier)
                .filter(isManagedReminderIdentifier)
        )
        let deliveredDates = deliveredNotifications.reduce(into: [UUID: Date]()) {
            result,
            notification in
            guard isManagedReminderIdentifier(notification.request.identifier),
                  let value = notification.request.content.userInfo["encounterID"] as? String,
                  let encounterID = UUID(uuidString: value)
            else {
                return
            }
            result[encounterID] = notification.date
        }

        return CommitmentNotificationState(
            pendingRequestIdentifiers: pendingIdentifiers,
            deliveredRequestIdentifiers: deliveredIdentifiers,
            deliveredEncounterDates: deliveredDates
        )
    }

    static func occupiedNotificationDates(
        excluding requestIdentifiers: Set<String>
    ) async -> [Date] {
        let center = UNUserNotificationCenter.current()
        async let pending = center.pendingNotificationRequests()
        async let delivered = center.deliveredNotifications()
        let (pendingRequests, deliveredNotifications) = await (pending, delivered)

        let pendingDates = pendingRequests.compactMap { request -> Date? in
            guard request.identifier.hasPrefix(applicationRequestPrefix),
                  !requestIdentifiers.contains(request.identifier)
            else {
                return nil
            }
            return notificationDate(request)
        }
        let deliveredDates = deliveredNotifications.compactMap { notification -> Date? in
            let identifier = notification.request.identifier
            guard identifier.hasPrefix(applicationRequestPrefix),
                  !requestIdentifiers.contains(identifier)
            else {
                return nil
            }
            return notification.date
        }
        return pendingDates + deliveredDates
    }

    static func isAuthorizationAvailable() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
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
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            return trigger.nextTriggerDate()
        }
        return nil
    }

    private static func notificationRequest(
        identifier: String,
        encounterID: UUID,
        plan: CommitmentReminderPlan,
        date: Date,
        showPreview: Bool,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let dateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let content = notificationContent(
            encounterID: encounterID,
            plan: plan,
            showPreview: showPreview
        )

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: false
            )
        )
    }

    private static func notificationContent(
        encounterID: UUID,
        plan: CommitmentReminderPlan,
        showPreview: Bool
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "과거의 불꽃"
        content.body = WhisperNotificationContentPolicy.commitmentReminderBody(
            quote: plan.quote,
            showPreview: showPreview
        )
        content.sound = .default
        content.threadIdentifier = "whisper.commitments"
        content.userInfo = [
            "recordID": plan.sourceRecordID.uuidString,
            "commitmentID": plan.id.uuidString,
            "encounterID": encounterID.uuidString
        ]

        return content
    }

#if DEBUG
    fileprivate static func scheduleDebugReminder(
        _ plan: CommitmentReminderPlan,
        after delay: TimeInterval
    ) async throws -> CommitmentReminderDebugScheduleResult {
        let center = UNUserNotificationCenter.current()
        guard try await ensureAuthorization(using: center) else {
            return .authorizationUnavailable
        }

        let interval = max(1, delay)
        let date = Date.now.addingTimeInterval(interval)
        let encounterID = UUID()
        let identifier = "\(debugCommitmentRequestPrefix(plan.id))\(encounterID.uuidString)"
        let content = notificationContent(
            encounterID: encounterID,
            plan: plan,
            showPreview: UserDefaults.standard.bool(forKey: showPreviewStorageKey)
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: interval,
                repeats: false
            )
        )
        try await center.add(request)
        return .scheduled(
            ScheduledCommitmentReminder(
                encounterID: encounterID,
                requestIdentifier: identifier,
                date: date
            )
        )
    }
#endif

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

    static func requestIdentifier(commitmentID: UUID, encounterID: UUID) -> String {
        "\(commitmentRequestPrefix(commitmentID))\(encounterID.uuidString)"
    }

    private static func commitmentRequestPrefix(_ commitmentID: UUID) -> String {
        "\(requestPrefix)\(commitmentID.uuidString)."
    }

    private static func isManagedReminderIdentifier(_ identifier: String) -> Bool {
        if identifier.hasPrefix(requestPrefix) {
            return true
        }
#if DEBUG
        return identifier.hasPrefix(debugRequestPrefix)
#else
        return false
#endif
    }

#if DEBUG
    private static func debugCommitmentRequestPrefix(_ commitmentID: UUID) -> String {
        "\(debugRequestPrefix)\(commitmentID.uuidString)."
    }
#endif
}

@MainActor
enum CommitmentReminderCoordinator {
    private static var isSynchronizing = false

    static func schedule(
        _ plan: CommitmentReminderPlan,
        in recordStore: RecordStore
    ) async -> CommitmentReminderApplicationResult {
        let scheduleGate = WhisperNotificationScheduleGate.shared
        await scheduleGate.acquire()
        guard !Task.isCancelled else {
            await scheduleGate.release()
            return .failed
        }
        let result = await rebuildScheduleExclusively(
            overriding: plan,
            in: recordStore,
            at: .now
        )
        await scheduleGate.release()
        return result
    }

#if DEBUG
    static func scheduleDebugReminder(
        in recordStore: RecordStore,
        after delay: TimeInterval = 10
    ) async -> CommitmentReminderDebugResult {
        let scheduleGate = WhisperNotificationScheduleGate.shared
        await scheduleGate.acquire()
        guard !Task.isCancelled,
              recordStore.refreshPersistentState()
        else {
            await scheduleGate.release()
            return .failed
        }

        guard let commitment = recordStore.commitments.first(where: {
            $0.lifecycleStatus() == .active
        }) else {
            await scheduleGate.release()
            return .noActiveCommitment
        }

        let oldIdentifiers = recordStore.futureDebugReminderRequestIdentifiers()
        await CommitmentReminderScheduler.cancel(
            requestIdentifiers: Array(oldIdentifiers)
        )
        guard recordStore.removeFutureDebugReminderState(
            requestIdentifiers: oldIdentifiers
        ) else {
            await scheduleGate.release()
            return .failed
        }

        let plan = CommitmentReminderPlan(
            id: commitment.id,
            sourceRecordID: commitment.sourceRecordID,
            name: commitment.name,
            quote: commitment.quote,
            reminderDates: []
        )

        do {
            switch try await CommitmentReminderScheduler.scheduleDebugReminder(
                plan,
                after: delay
            ) {
            case .authorizationUnavailable:
                await scheduleGate.release()
                return .authorizationUnavailable
            case let .scheduled(reminder):
                guard recordStore.addEncounter(
                    commitmentID: commitment.id,
                    scheduledAt: reminder.date,
                    notificationIdentifier: reminder.requestIdentifier
                ) != nil else {
                    await CommitmentReminderScheduler.cancel(
                        requestIdentifiers: [reminder.requestIdentifier]
                    )
                    await scheduleGate.release()
                    return .failed
                }
                await scheduleGate.release()
                return .scheduled(reminder.date)
            }
        } catch {
            let nsError = error as NSError
            WhisperDiagnostics.reminderLogger.error(
                "Debug reminder failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            await scheduleGate.release()
            return .failed
        }
    }

    static func cancelDebugReminders(in recordStore: RecordStore) async -> Bool {
        let scheduleGate = WhisperNotificationScheduleGate.shared
        await scheduleGate.acquire()
        let identifiers = recordStore.futureDebugReminderRequestIdentifiers()
        await CommitmentReminderScheduler.cancel(
            requestIdentifiers: Array(identifiers)
        )
        let didRemoveState = recordStore.removeFutureDebugReminderState(
            requestIdentifiers: identifiers
        )
        await scheduleGate.release()
        return didRemoveState
    }
#endif

    @discardableResult
    static func cancel(
        commitmentIDs: [UUID],
        in recordStore: RecordStore,
        at date: Date = .now
    ) async -> Bool {
        guard !commitmentIDs.isEmpty else { return true }

        let scheduleGate = WhisperNotificationScheduleGate.shared
        await scheduleGate.acquire()
        await CommitmentReminderScheduler.cancel(commitmentIDs: commitmentIDs)
        let didRemoveState = recordStore.removeFutureReminderState(
            commitmentIDs: Set(commitmentIDs),
            at: date
        )
        await scheduleGate.release()
        return didRemoveState
    }

    private static func rebuildScheduleExclusively(
        overriding plan: CommitmentReminderPlan?,
        in recordStore: RecordStore,
        at date: Date
    ) async -> CommitmentReminderApplicationResult {
        guard recordStore.refreshPersistentState() else {
            return .failed
        }

        let calendar = Calendar.current
        let inputs = recordStore.reminderAllocationInputs(
            overriding: plan,
            at: date
        )
        let previousRequestIdentifiers = recordStore
            .replaceableFutureCommitmentRequestIdentifiers(
                explicitlyReplanningCommitmentID: plan?.id,
                at: date
            )
        let storedOccupiedDates = recordStore.occupiedNotificationDates(
            excluding: previousRequestIdentifiers,
            at: date
        )
        let systemOccupiedDates = await CommitmentReminderScheduler
            .occupiedNotificationDates(excluding: previousRequestIdentifiers)
        let occupiedDates = uniqueOccupiedDates(
            storedOccupiedDates + systemOccupiedDates,
            at: date,
            calendar: calendar
        )
        let allocation = CommitmentReminderGlobalPolicy.allocate(
            inputs: inputs,
            occupiedDates: occupiedDates,
            policy: CommitmentReminderScheduler.allocationPolicy(
                at: date,
                calendar: calendar
            )
        )

        if !allocation.unassignedCommitmentIDs.isEmpty {
            WhisperDiagnostics.reminderLogger.notice(
                "Could not allocate every reminder for \(allocation.unassignedCommitmentIDs.count, privacy: .public) commitments"
            )
        }

        let previousOverrideIdentifiers = plan.map {
            recordStore.replaceableNotificationIdentifiers(for: $0.id, at: date)
        } ?? []

        do {
            switch try await CommitmentReminderScheduler.schedule(
                allocation,
                inputs: inputs,
                replacingRequestIdentifiers: previousRequestIdentifiers
            ) {
            case .authorizationUnavailable:
                if let plan {
                    restorePreviousReminderDateIfNeeded(
                        commitmentID: plan.id,
                        previousRequestIdentifiers: previousOverrideIdentifiers,
                        in: recordStore
                    )
                }
                return .authorizationUnavailable
            case let .scheduled(remindersByCommitment, replacementToken):
                let slotDrafts = makeSlotDrafts(
                    remindersByCommitment: remindersByCommitment,
                    inputs: inputs,
                    createdAt: date,
                    calendar: calendar
                )
                guard recordStore.replaceReminderSchedule(
                    replacingRequestIdentifiers: previousRequestIdentifiers,
                    remindersByCommitment: remindersByCommitment,
                    slotDrafts: slotDrafts,
                    at: date
                ) else {
                    await CommitmentReminderScheduler.rollback(replacementToken)
                    if let plan {
                        restorePreviousReminderDateIfNeeded(
                            commitmentID: plan.id,
                            previousRequestIdentifiers: previousOverrideIdentifiers,
                            in: recordStore
                        )
                    }
                    return .failed
                }
                CommitmentReminderScheduler.commit(replacementToken)
                return .scheduled
            }
        } catch {
            let nsError = error as NSError
            WhisperDiagnostics.reminderLogger.error(
                "Reminder schedule failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            if let plan {
                restorePreviousReminderDateIfNeeded(
                    commitmentID: plan.id,
                    previousRequestIdentifiers: previousOverrideIdentifiers,
                    in: recordStore
                )
            }
            return .failed
        }
    }

    static func synchronize(with recordStore: RecordStore) async {
        guard !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }

        let scheduleGate = WhisperNotificationScheduleGate.shared
        await scheduleGate.acquire()
        guard !Task.isCancelled else {
            await scheduleGate.release()
            return
        }

        guard recordStore.refreshPersistentState() else {
            await scheduleGate.release()
            return
        }

        let state = await CommitmentReminderScheduler.currentNotificationState()
        guard recordStore.reconcileReminderNotifications(with: state) else {
            await scheduleGate.release()
            return
        }
        guard recordStore.backfillNotificationDaySlots() else {
            await scheduleGate.release()
            return
        }

        let orphanedIdentifiers = state.orphanedRequestIdentifiers(
            trackedRequestIdentifiers: recordStore.trackedNotificationIdentifiers
        )
        if !orphanedIdentifiers.isEmpty {
            WhisperDiagnostics.reminderLogger.notice(
                "Removing \(orphanedIdentifiers.count, privacy: .public) orphaned reminder requests"
            )
            await CommitmentReminderScheduler.cancel(
                requestIdentifiers: Array(orphanedIdentifiers)
            )
        }

        guard await CommitmentReminderScheduler.isAuthorizationAvailable() else {
            await scheduleGate.release()
            return
        }

        _ = await rebuildScheduleExclusively(
            overriding: nil,
            in: recordStore,
            at: .now
        )
        await scheduleGate.release()
    }

    private static func makeSlotDrafts(
        remindersByCommitment: [UUID: [ScheduledCommitmentReminder]],
        inputs: [CommitmentReminderAllocationInput],
        createdAt: Date,
        calendar: Calendar
    ) -> [NotificationDaySlotDraft] {
        let plansByID = inputs.reduce(into: [UUID: CommitmentReminderPlan]()) {
            result,
            input in
            result[input.plan.id] = input.plan
        }

        var drafts: [NotificationDaySlotDraft] = []
        for (commitmentID, reminders) in remindersByCommitment {
            guard let plan = plansByID[commitmentID] else { continue }
            drafts.append(contentsOf: reminders.map { reminder in
                NotificationDaySlotDraft(
                    dayKey: WhisperNotificationDayKey.make(
                        for: reminder.date,
                        calendar: calendar
                    ),
                    scheduledAt: reminder.date,
                    requestIdentifier: reminder.requestIdentifier,
                    sourceStorage: WhisperNotificationSource.commitment.rawValue,
                    commitmentID: commitmentID,
                    recordID: plan.sourceRecordID,
                    createdAt: createdAt
                )
            })
        }
        return drafts
    }

    private static func uniqueOccupiedDates(
        _ dates: [Date],
        at date: Date,
        calendar: Calendar
    ) -> [Date] {
        Dictionary(
            grouping: dates,
            by: { WhisperNotificationDayKey.make(for: $0, calendar: calendar) }
        )
        .values
        .compactMap { datesOnDay in
            datesOnDay.filter { $0 > date }.min() ?? datesOnDay.max()
        }
        .sorted()
    }

    private static func restorePreviousReminderDateIfNeeded(
        commitmentID: UUID,
        previousRequestIdentifiers: Set<String>,
        in recordStore: RecordStore
    ) {
        guard !previousRequestIdentifiers.isEmpty else { return }
        _ = recordStore.restoreNextReminderFromScheduledEncounters(
            commitmentID: commitmentID
        )
    }
}
