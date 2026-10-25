//
//  WhisperFocusFilter.swift
//  Whisper
//

import AppIntents
import UserNotifications

struct WhisperRecordEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "불꽃"
    static var defaultQuery = WhisperRecordEntityQuery()

    let id: String
    let title: String
    let contentPreview: String

    init(record: WhisperRecord) {
        id = record.id.uuidString
        title = record.title
        contentPreview = String(record.content.prefix(60))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(contentPreview)"
        )
    }
}

struct WhisperRecordEntityQuery: EntityQuery {
    func entities(for identifiers: [WhisperRecordEntity.ID]) async throws
        -> [WhisperRecordEntity]
    {
        guard CommitmentReminderFeature.isEnabled else { return [] }
        return await MainActor.run {
            let identifierSet = Set(identifiers)
            return RecordStore().records
                .filter { identifierSet.contains($0.id.uuidString) }
                .map(WhisperRecordEntity.init(record:))
        }
    }

    func suggestedEntities() async throws -> [WhisperRecordEntity] {
        guard CommitmentReminderFeature.isEnabled else { return [] }
        return await MainActor.run {
            RecordStore().records.map(WhisperRecordEntity.init(record:))
        }
    }
}

struct WhisperFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "다시 만날 불꽃 선택"
    static var description = IntentDescription(
        "이 집중 모드가 시작될 때 다시 만날 Whisper 불꽃을 선택해요."
    )
    static var supportedModes: IntentModes = .background

    @Parameter(title: "다시 만날 불꽃")
    var flames: [WhisperRecordEntity]?

    init() {}

    var displayRepresentation: DisplayRepresentation {
        guard let flames, !flames.isEmpty else {
            return DisplayRepresentation(
                title: "Whisper",
                subtitle: "다시 만날 불꽃 선택"
            )
        }

        return DisplayRepresentation(
            title: "Whisper",
            subtitle: "\(flames.count)개의 불꽃"
        )
    }

    func perform() async throws -> some IntentResult {
        guard CommitmentReminderFeature.isEnabled else { return .result() }
        guard let flames, !flames.isEmpty else { return .result() }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional
        else {
            return .result()
        }

        let gate = WhisperNotificationScheduleGate.shared
        await gate.acquire()
        guard !Task.isCancelled else {
            await gate.release()
            return .result()
        }
        do {
            try await scheduleFocusReminderIfTodayIsAvailable(flames: flames)
        } catch {
            await gate.release()
            throw error
        }
        await gate.release()
        return .result()
    }

    @MainActor
    private func scheduleFocusReminderIfTodayIsAvailable(
        flames: [WhisperRecordEntity]
    ) async throws {
        let now = Date.now
        let calendar = Calendar.current
        let dayKey = WhisperNotificationDayKey.make(for: now, calendar: calendar)
        let recordStore = RecordStore()

        guard recordStore.isPersistenceAvailable,
              recordStore.refreshPersistentState(),
              recordStore.backfillNotificationDaySlots(at: now)
        else {
            return
        }
        let systemDates = await CommitmentReminderScheduler
            .occupiedNotificationDates(excluding: [])
        let isSystemDayOccupied = systemDates.contains {
            calendar.isDate($0, inSameDayAs: now)
        }
        guard recordStore.refreshPersistentState(),
              recordStore.notificationSlot(dayKey: dayKey) == nil,
              !isSystemDayOccupied
        else {
            return
        }

        let selectedIDs = Set(flames.compactMap { UUID(uuidString: $0.id) })
        let records = recordStore.records.filter { selectedIDs.contains($0.id) }
        guard !records.isEmpty else { return }

        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let reminder = records[day % records.count]
        let copy = WhisperNotificationContentPolicy.focusReminderCopy(
            title: reminder.title,
            content: reminder.content,
            showPreview: UserDefaults.standard.bool(
                forKey: CommitmentReminderScheduler.showPreviewStorageKey
            )
        )
        let content = UNMutableNotificationContent()
        content.title = String(localized: "다시 만난 불꽃", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        content.subtitle = copy.subtitle ?? ""
        content.body = copy.body
        content.sound = .default
        content.threadIdentifier = "whisper.focus.records"
        content.userInfo = [
            "recordID": reminder.id.uuidString,
            "notificationDayKey": dayKey,
            "notificationSource": WhisperNotificationSource.focus.rawValue
        ]

        let requestIdentifier = "whisper.focus.\(dayKey)"
        let center = UNUserNotificationCenter.current()
        let request = UNNotificationRequest(
            identifier: requestIdentifier,
            content: content,
            trigger: nil
        )

        let didReserveSlot = recordStore.saveNotificationSlot(
            NotificationDaySlotDraft(
                dayKey: dayKey,
                scheduledAt: now,
                requestIdentifier: requestIdentifier,
                sourceStorage: WhisperNotificationSource.focus.rawValue,
                recordID: reminder.id,
                createdAt: now
            )
        )
        guard didReserveSlot,
              let reservedSlot = recordStore.notificationSlot(
                requestIdentifier: requestIdentifier
              ),
              reservedSlot.dayKey == dayKey,
              reservedSlot.sourceStorage == WhisperNotificationSource.focus.rawValue,
              reservedSlot.recordID == reminder.id,
              reservedSlot.consumedAt == nil
        else {
            return
        }
        let reservedSlotID = reservedSlot.id

        do {
            try await center.add(request)
        } catch {
            rollbackFocusNotification(
                requestIdentifier: requestIdentifier,
                using: center
            )
            _ = recordStore.removeUnconsumedNotificationSlot(
                id: reservedSlotID,
                requestIdentifier: requestIdentifier
            )
            throw error
        }

        // If this save fails, the unconsumed slot remains persisted and still
        // protects today from another notification.
        _ = recordStore.markNotificationSlotConsumed(
            requestIdentifier: requestIdentifier,
            at: now
        )
    }

    @MainActor
    private func rollbackFocusNotification(
        requestIdentifier: String,
        using center: UNUserNotificationCenter
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
    }
}
