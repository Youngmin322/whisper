//
//  RecordStore.swift
//  Whisper
//

import Foundation
import Observation
import SwiftData

private struct LegacyWhisperRecord: Codable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: Date
}

@MainActor
@Observable
final class RecordStore {
    private(set) var records: [WhisperRecord] = []
    private(set) var commitments: [WhisperCommitment] = []
    private(set) var encounters: [ReminderEncounter] = []
    private(set) var notificationSlots: [NotificationDaySlot] = []
    private(set) var journals: [DailyJournal] = []
    private(set) var persistenceError: String?
    private(set) var persistenceSupportCode: String?
    private(set) var persistenceDiagnosticSummary: String?
    private(set) var isPersistenceAvailable = true

    @ObservationIgnored private let modelContainer: ModelContainer?
    @ObservationIgnored private let modelContext: ModelContext?
    @ObservationIgnored private let legacyStorageKey = "whisper.records"

    init(isStoredInMemoryOnly: Bool = false) {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        do {
            let schema = Schema(versionedSchema: WhisperSchemaV5.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: WhisperMigrationPlan.self,
                configurations: configuration
            )
            modelContainer = container
            modelContext = container.mainContext
        } catch {
            modelContainer = nil
            modelContext = nil
            isPersistenceAvailable = false
            recordPersistenceError(error, operation: "model-container-initialization")
            return
        }

        reload()

        if !isStoredInMemoryOnly {
            migrateLegacyRecordsIfNeeded()
        }
    }

    var latestRecord: WhisperRecord? {
        records.first
    }

    func journal(on date: Date, calendar: Calendar = .current) -> DailyJournal? {
        journals.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func uncollectedMoments(on date: Date, calendar: Calendar = .current) -> [WhisperRecord] {
        let collectedIDs = Set(journals.flatMap(\.sourceRecordIDs))
        return records
            .filter {
                calendar.isDate($0.createdAt, inSameDayAs: date)
                    && !collectedIDs.contains($0.id)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func saveJournal(
        on date: Date,
        title: String,
        body: String,
        sourceRecordIDs: [UUID],
        emotion: String? = nil,
        calendar: Calendar = .current
    ) -> DailyJournal? {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return nil
        }
        let day = calendar.startOfDay(for: date)
        let key = JournalDayKey.make(for: date, calendar: calendar)
        var seenIDs = Set<UUID>()
        let ids = sourceRecordIDs.filter { seenIDs.insert($0).inserted }
        let existing = journals.first { $0.dayKey == key }
        if let existing {
            existing.update(title: title, body: body, sourceRecordIDs: ids)
            if let emotion { existing.emotion = emotion }
        } else {
            modelContext.insert(DailyJournal(
                dayKey: key,
                date: day,
                title: title,
                body: body,
                reflection: "",
                emotion: emotion,
                sourceRecordIDs: ids
            ))
        }
        guard saveChanges(reloadAfterSave: true) else { return nil }
        return journals.first { $0.dayKey == key }
    }

    @discardableResult
    func deleteJournal(_ journal: DailyJournal) -> Bool {
        guard let modelContext,
              let stored = journals.first(where: { $0.id == journal.id }) else {
            if modelContext == nil { setUnavailablePersistenceError() }
            return false
        }
        modelContext.delete(stored)
        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func add(
        title: String,
        content: String,
        createdAt: Date = .now,
        focusMode: String? = nil,
        emotion: String? = nil,
        photoData: Data? = nil
    ) -> Bool {
        addAndReturn(
            title: title,
            content: content,
            createdAt: createdAt,
            focusMode: focusMode,
            emotion: emotion,
            photoData: photoData
        ) != nil
    }

    @discardableResult
    func addAndReturn(
        title: String,
        content: String,
        createdAt: Date = .now,
        focusMode: String? = nil,
        emotion: String? = nil,
        photoData: Data? = nil
    ) -> WhisperRecord? {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return nil
        }
        let record = WhisperRecord(
            title: title,
            content: content,
            createdAt: createdAt,
            focusMode: focusMode,
            emotion: emotion,
            photoData: photoData
        )
        modelContext.insert(record)
        guard saveChanges(reloadAfterSave: true) else { return nil }
        return self.record(withID: record.id)
    }

    @discardableResult
    func update(
        _ record: WhisperRecord,
        title: String,
        content: String,
        emotion: String?,
        photoData: Data?
    ) -> Bool {
        guard modelContext != nil else {
            setUnavailablePersistenceError()
            return false
        }
        record.title = title
        record.content = content
        record.emotion = emotion
        record.photoData = photoData
        record.updatedAt = .now
        return saveChanges()
    }

    @discardableResult
    func delete(_ record: WhisperRecord) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }
        let relatedCommitments = commitments.filter { $0.sourceRecordID == record.id }
        let commitmentIDs = relatedCommitments.map(\.id)
        encounters
            .filter { commitmentIDs.contains($0.commitmentID) }
            .forEach(modelContext.delete)
        relatedCommitments.forEach(modelContext.delete)
        modelContext.delete(record)
        let didSave = saveChanges(reloadAfterSave: true)

        if didSave {
            Task {
                await CommitmentReminderCoordinator.cancel(
                    commitmentIDs: commitmentIDs,
                    in: self
                )
            }
        }

        return didSave
    }

    var activeCommitmentSnapshots: [CommitmentSnapshot] {
        commitments
            .filter { $0.lifecycleStatus() == .active }
            .prefix(8)
            .map { makeSnapshot(from: $0) }
    }

    func commitment(sourceRecordID: UUID) -> WhisperCommitment? {
        commitments.first {
            $0.sourceRecordID == sourceRecordID && $0.lifecycleStatus() == .active
        }
    }

    @discardableResult
    func rememberCommitment(
        sourceRecordID: UUID,
        name: String,
        quote: String,
        topics: [String],
        reminderTiming: CommitmentReminderTiming,
        firstReminderDate: Date? = nil,
        now: Date = .now
    ) -> CommitmentReminderPlan? {
        guard let modelContext,
              records.contains(where: { $0.id == sourceRecordID })
        else {
            if modelContext == nil {
                setUnavailablePersistenceError()
            }
            return nil
        }
        if let existing = commitment(sourceRecordID: sourceRecordID) {
            let plan = reminderPlan(
                for: existing,
                anchorDate: now,
                timing: reminderTiming,
                firstReminderDate: firstReminderDate
            )
            existing.nextReminderAt = plan.reminderDates.first
            guard saveChanges(),
                  let saved = self.commitment(sourceRecordID: sourceRecordID)
            else {
                return nil
            }
            return reminderPlan(
                for: saved,
                anchorDate: now,
                timing: reminderTiming,
                firstReminderDate: firstReminderDate
            )
        }

        let reminderDates = makeReminderDates(
            anchorDate: now,
            timing: reminderTiming,
            firstReminderDate: firstReminderDate
        )

        let commitment = WhisperCommitment(
            sourceRecordID: sourceRecordID,
            name: name,
            quote: quote,
            topics: topics,
            createdAt: now,
            nextReminderAt: reminderDates.first
        )
        modelContext.insert(commitment)

        guard saveChanges(reloadAfterSave: true),
              let saved = self.commitment(sourceRecordID: sourceRecordID)
        else {
            return nil
        }

        return reminderPlan(
            for: saved,
            anchorDate: now,
            timing: reminderTiming,
            firstReminderDate: firstReminderDate
        )
    }

    @discardableResult
    func rememberCommitment(
        sourceRecordID: UUID,
        name: String,
        quote: String,
        topics: [String],
        reminderProfile: CommitmentReminderProfile,
        firstReminderDate: Date? = nil,
        now: Date = .now
    ) -> CommitmentReminderPlan? {
        guard let modelContext,
              records.contains(where: { $0.id == sourceRecordID })
        else {
            if modelContext == nil {
                setUnavailablePersistenceError()
            }
            return nil
        }

        if let existing = commitment(sourceRecordID: sourceRecordID) {
            existing.reminderProfile = reminderProfile
            let plan = policyReminderPlan(
                for: existing,
                event: .remembered,
                firstReminderDate: firstReminderDate,
                now: now
            )
            existing.nextReminderAt = plan.reminderDates.first
            return saveChanges() ? plan : nil
        }

        let commitment = WhisperCommitment(
            sourceRecordID: sourceRecordID,
            name: name,
            quote: quote,
            topics: topics,
            createdAt: now,
            reminderProfile: reminderProfile
        )
        let plan = policyReminderPlan(
            for: commitment,
            event: .remembered,
            firstReminderDate: firstReminderDate,
            now: now
        )
        commitment.nextReminderAt = plan.reminderDates.first
        modelContext.insert(commitment)

        guard saveChanges(reloadAfterSave: true),
              let saved = self.commitment(sourceRecordID: sourceRecordID)
        else {
            return nil
        }
        return policyReminderPlan(
            for: saved,
            event: .remembered,
            firstReminderDate: firstReminderDate,
            now: now
        )
    }

    func continueCommitment(
        _ id: UUID,
        reminderTiming: CommitmentReminderTiming,
        now: Date = .now
    ) -> CommitmentReminderPlan? {
        guard let commitment = activeCommitment(withID: id, at: now) else {
            return nil
        }

        commitment.lastContinuedAt = now
        commitment.continuationCount += 1
        commitment.nextReminderAt = makeReminderDates(anchorDate: now, timing: reminderTiming).first

        guard saveChanges(),
              let saved = commitments.first(where: { $0.id == id })
        else {
            return nil
        }

        return reminderPlan(
            for: saved,
            anchorDate: now,
            timing: reminderTiming
        )
    }

    func continueCommitment(
        _ id: UUID,
        reminderProfile: CommitmentReminderProfile,
        now: Date = .now
    ) -> CommitmentReminderPlan? {
        guard let commitment = activeCommitment(withID: id, at: now) else {
            return nil
        }

        commitment.lastContinuedAt = now
        commitment.continuationCount += 1
        commitment.reminderProfile = reminderProfile
        let plan = policyReminderPlan(for: commitment, event: .continued, now: now)
        commitment.nextReminderAt = plan.reminderDates.first
        return saveChanges() ? plan : nil
    }

    func nextReminderPlanAfterKeeping(
        commitmentID: UUID,
        now: Date = .now
    ) -> CommitmentReminderPlan? {
        guard let commitment = activeCommitment(withID: commitmentID, at: now) else {
            return nil
        }
        let plan = policyReminderPlan(for: commitment, event: .kept, now: now)
        commitment.nextReminderAt = plan.reminderDates.first
        return saveChanges() ? plan : nil
    }

    func rescheduleCommitment(
        _ id: UUID,
        reminderTiming: CommitmentReminderTiming,
        now: Date = .now
    ) -> CommitmentReminderPlan? {
        guard let commitment = activeCommitment(withID: id, at: now) else {
            return nil
        }

        commitment.nextReminderAt = makeReminderDates(anchorDate: now, timing: reminderTiming).first

        guard saveChanges(),
              let saved = commitments.first(where: { $0.id == id })
        else {
            return nil
        }

        return reminderPlan(for: saved, anchorDate: now, timing: reminderTiming)
    }

    func rescheduleCommitment(
        _ id: UUID,
        firstReminderDate: Date,
        now: Date = .now
    ) -> CommitmentReminderPlan? {
        guard firstReminderDate > now,
              let commitment = activeCommitment(withID: id, at: now)
        else {
            return nil
        }

        let reminderDates = [firstReminderDate]
        commitment.nextReminderAt = firstReminderDate

        guard saveChanges(),
              let saved = commitments.first(where: { $0.id == id })
        else {
            return nil
        }

        return makePlan(for: saved, reminderDates: reminderDates)
    }

    func reminderPlanningContext(for commitmentID: UUID) -> CommitmentReminderPlanningContext? {
        guard let commitment = commitments.first(where: {
            $0.id == commitmentID && $0.lifecycleStatus() == .active
        }) else {
            return nil
        }

        let recentRecords = records
            .prefix(3)
            .map {
                ReminderRecordSnapshot(
                    title: $0.title,
                    content: $0.content,
                    createdAt: $0.createdAt
                )
            }

        return CommitmentReminderPlanningContext(
            commitment: makeSnapshot(from: commitment),
            recentRecords: recentRecords
        )
    }

    func reminderRecoveryPlans(at date: Date = .now) -> [CommitmentReminderPlan] {
        commitments.compactMap { commitment in
            guard commitment.lifecycleStatus(at: date) == .active,
                  !hasFutureScheduledEncounter(for: commitment.id, at: date)
            else {
                return nil
            }

            let retainedFirstReminderDate = commitment.nextReminderAt.flatMap {
                $0 > date ? $0 : nil
            }
            return policyReminderPlan(
                for: commitment,
                event: .recovery,
                firstReminderDate: retainedFirstReminderDate,
                now: date
            )
        }
    }

    func replaceableNotificationIdentifiers(
        for commitmentID: UUID,
        at date: Date = .now
    ) -> Set<String> {
        Set(
            encounters.compactMap { encounter in
                guard encounter.commitmentID == commitmentID,
                      encounter.presentedAt == nil,
                      encounter.openedAt == nil,
                      encounter.scheduledAt > date
                else {
                    return nil
                }
                return encounter.notificationIdentifier
            }
        )
    }

    var trackedNotificationIdentifiers: Set<String> {
        Set(encounters.compactMap(\.notificationIdentifier))
    }

    var occupiedNotificationDayKeys: Set<String> {
        Set(notificationSlots.map(\.dayKey))
    }

    func notificationSlot(dayKey: String) -> NotificationDaySlot? {
        notificationSlots.first { $0.dayKey == dayKey }
    }

    func notificationSlot(requestIdentifier: String) -> NotificationDaySlot? {
        notificationSlots.first { $0.requestIdentifier == requestIdentifier }
    }

    func notificationSlots(commitmentID: UUID) -> [NotificationDaySlot] {
        notificationSlots.filter { $0.commitmentID == commitmentID }
    }

    func reminderAllocationInputs(
        overriding overridePlan: CommitmentReminderPlan?,
        at date: Date = .now
    ) -> [CommitmentReminderAllocationInput] {
        commitments.compactMap { commitment in
            guard commitment.lifecycleStatus(at: date) != .released else { return nil }

            if let overridePlan, overridePlan.id == commitment.id {
                return CommitmentReminderAllocationInput(
                    plan: overridePlan,
                    lastEncounteredAt: commitment.lastEncounteredAt,
                    createdAt: commitment.createdAt
                )
            }

            if commitment.lifecycleStatus(at: date) == .paused,
               let pausedUntil = commitment.pausedUntil,
               pausedUntil > date {
                return CommitmentReminderAllocationInput(
                    plan: makePlan(for: commitment, reminderDates: [pausedUntil]),
                    lastEncounteredAt: commitment.lastEncounteredAt,
                    createdAt: commitment.createdAt
                )
            }

            guard commitment.lifecycleStatus(at: date) == .active else { return nil }

            let pastEncounterWithoutPreferenceChange = encounters.contains { encounter in
                encounter.commitmentID == commitment.id
                    && encounter.notificationIdentifier != nil
                    && encounter.reaction == nil
                    && encounter.scheduledAt <= date
            }
            let slotDates = notificationSlots
                .filter {
                    $0.sourceStorage == WhisperNotificationSource.commitment.rawValue
                        && $0.commitmentID == commitment.id
                        && $0.consumedAt == nil
                        && $0.scheduledAt > date
                }
                .map(\.scheduledAt)
                .sorted()
            let encounterDates = encounters
                .filter {
                    $0.commitmentID == commitment.id
                        && $0.notificationIdentifier != nil
                        && $0.presentedAt == nil
                        && $0.openedAt == nil
                        && $0.scheduledAt > date
                }
                .map(\.scheduledAt)
                .sorted()
            let retainedDates = slotDates.isEmpty ? encounterDates : slotDates

            // 아무 선택도 하지 않은 만남은 기본적으로 계속 기억하는 것으로 봐요.
            // 이미 잡힌 미래 알림은 그대로 두고, 모두 소진된 뒤에만 복구 일정을 만들어요.
            if pastEncounterWithoutPreferenceChange && !retainedDates.isEmpty {
                return nil
            }

            let plan: CommitmentReminderPlan
            if !retainedDates.isEmpty {
                plan = makePlan(
                    for: commitment,
                    reminderDates: Array(retainedDates.prefix(1))
                )
            } else {
                let retainedFirstDate = commitment.nextReminderAt.flatMap {
                    $0 > date ? $0 : nil
                }
                plan = policyReminderPlan(
                    for: commitment,
                    event: .recovery,
                    firstReminderDate: retainedFirstDate,
                    now: date
                )
            }

            return CommitmentReminderAllocationInput(
                plan: plan,
                lastEncounteredAt: commitment.lastEncounteredAt,
                createdAt: commitment.createdAt
            )
        }
    }

    func commitmentIDsPreservingFutureReminders(
        at date: Date = .now
    ) -> Set<UUID> {
        Set(commitments.compactMap { commitment in
            guard commitment.lifecycleStatus(at: date) == .active,
                  encounters.contains(where: { encounter in
                      encounter.commitmentID == commitment.id
                          && encounter.notificationIdentifier != nil
                          && encounter.reaction == nil
                          && encounter.scheduledAt <= date
                  })
            else {
                return nil
            }
            return commitment.id
        })
    }

    func replaceableFutureCommitmentRequestIdentifiers(
        explicitlyReplanningCommitmentID: UUID? = nil,
        at date: Date = .now
    ) -> Set<String> {
        var protectedCommitmentIDs = commitmentIDsPreservingFutureReminders(at: date)
        if let explicitlyReplanningCommitmentID {
            protectedCommitmentIDs.remove(explicitlyReplanningCommitmentID)
        }

        let slotIdentifiers = notificationSlots.compactMap { slot -> String? in
            guard slot.sourceStorage == WhisperNotificationSource.commitment.rawValue,
                  slot.commitmentID.map(protectedCommitmentIDs.contains) != true,
                  slot.consumedAt == nil,
                  slot.scheduledAt > date
            else {
                return nil
            }
            return slot.requestIdentifier
        }
        let encounterIdentifiers = encounters.compactMap { encounter -> String? in
            guard !protectedCommitmentIDs.contains(encounter.commitmentID),
                  encounter.presentedAt == nil,
                  encounter.openedAt == nil,
                  encounter.scheduledAt > date
            else {
                return nil
            }
            return encounter.notificationIdentifier
        }
        return Set(slotIdentifiers).union(encounterIdentifiers)
    }

    func occupiedNotificationDates(
        excluding requestIdentifiers: Set<String> = [],
        at date: Date = .now
    ) -> [Date] {
        var dates = notificationSlots.compactMap { slot -> Date? in
            guard !requestIdentifiers.contains(slot.requestIdentifier) else { return nil }
            return slot.scheduledAt
        }

        let slottedIdentifiers = Set(notificationSlots.map(\.requestIdentifier))
        dates.append(contentsOf: encounters.compactMap { encounter -> Date? in
            guard let identifier = encounter.notificationIdentifier,
                  !requestIdentifiers.contains(identifier),
                  !slottedIdentifiers.contains(identifier)
            else {
                return nil
            }
            return encounter.scheduledAt
        })
        return dates
    }

    func reminderBehaviorSummary(
        for commitmentID: UUID,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> ReminderBehaviorSummary {
        let pastEncounters = encounters
            .filter {
                $0.commitmentID == commitmentID
                    && $0.scheduledAt <= date
            }
            .sorted { $0.scheduledAt > $1.scheduledAt }

        let consecutiveUnopenedCount = pastEncounters
            .prefix { $0.openedAt == nil }
            .count
        let weekStart = calendar.date(byAdding: .day, value: -7, to: date) ?? date
        let notificationsLast7Days = pastEncounters.count {
            $0.scheduledAt >= weekStart
        }
        let lastReaction = pastEncounters.first(where: { $0.reaction != nil })?.reaction
        let openedHours = pastEncounters.compactMap { encounter in
            encounter.openedAt.map { calendar.component(.hour, from: $0) }
        }
        let preferredOpenHour: Int?
        if openedHours.count >= 3 {
            let counts = Dictionary(grouping: openedHours, by: { $0 }).mapValues(\.count)
            preferredOpenHour = counts.max { lhs, rhs in
                lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
            }?.key
        } else {
            preferredOpenHour = nil
        }

        return ReminderBehaviorSummary(
            consecutiveUnopenedCount: consecutiveUnopenedCount,
            notificationsLast7Days: notificationsLast7Days,
            lastReaction: lastReaction,
            preferredOpenHour: preferredOpenHour,
            lastEncounteredAt: pastEncounters.first?.presentedAt
        )
    }

    @discardableResult
    func backfillNotificationDaySlots(at date: Date = .now) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }

        var occupiedDayKeys = Set(notificationSlots.map(\.dayKey))
        let existingIdentifiers = Set(notificationSlots.map(\.requestIdentifier))
        var didInsert = false

        for encounter in encounters.sorted(by: { $0.scheduledAt < $1.scheduledAt }) {
            guard let identifier = encounter.notificationIdentifier,
                  !existingIdentifiers.contains(identifier),
                  let commitment = commitments.first(where: { $0.id == encounter.commitmentID })
            else {
                continue
            }

            let dayKey = WhisperNotificationDayKey.make(for: encounter.scheduledAt)
            guard !occupiedDayKeys.contains(dayKey) else { continue }

            modelContext.insert(
                NotificationDaySlot(
                    dayKey: dayKey,
                    scheduledAt: encounter.scheduledAt,
                    requestIdentifier: identifier,
                    sourceStorage: WhisperNotificationSource.commitment.rawValue,
                    commitmentID: encounter.commitmentID,
                    recordID: commitment.sourceRecordID,
                    consumedAt: encounter.openedAt
                        ?? encounter.presentedAt
                        ?? (encounter.scheduledAt <= date ? encounter.scheduledAt : nil)
                )
            )
            occupiedDayKeys.insert(dayKey)
            didInsert = true
        }

        return didInsert ? saveChanges(reloadAfterSave: true) : true
    }

    @discardableResult
    func replaceReminderSchedule(
        replacingRequestIdentifiers: Set<String>,
        remindersByCommitment: [UUID: [ScheduledCommitmentReminder]],
        slotDrafts: [NotificationDaySlotDraft],
        at date: Date = .now
    ) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }

        let dayKeys = slotDrafts.map(\.dayKey)
        let newRequestIdentifiers = slotDrafts.map(\.requestIdentifier)
        guard Set(dayKeys).count == dayKeys.count,
              Set(newRequestIdentifiers).count == newRequestIdentifiers.count,
              Set(remindersByCommitment.keys).allSatisfy({ commitmentID in
                  commitments.contains {
                      $0.id == commitmentID && $0.lifecycleStatus(at: date) != .released
                  }
              }),
              Set(remindersByCommitment.values.flatMap { $0.map(\.requestIdentifier) })
                == Set(newRequestIdentifiers)
        else {
            return false
        }

        let replacingSlots = notificationSlots.filter {
            replacingRequestIdentifiers.contains($0.requestIdentifier)
        }
        guard replacingSlots.allSatisfy({ $0.consumedAt == nil && $0.scheduledAt > date }) else {
            return false
        }

        let replacingSlotIDs = Set(replacingSlots.map(\.id))
        let protectedDayKeys = Set(
            notificationSlots
                .filter { !replacingSlotIDs.contains($0.id) }
                .map(\.dayKey)
        )
        guard protectedDayKeys.isDisjoint(with: dayKeys) else { return false }

        var reusableSlotsByDay = Dictionary(
            uniqueKeysWithValues: replacingSlots.map { ($0.dayKey, $0) }
        )
        for draft in slotDrafts {
            if let slot = reusableSlotsByDay.removeValue(forKey: draft.dayKey) {
                apply(draft, to: slot)
            } else {
                modelContext.insert(makeNotificationSlot(from: draft))
            }
        }
        reusableSlotsByDay.values.forEach(modelContext.delete)

        let replacedCommitmentIDs = Set(
            encounters.compactMap { encounter -> UUID? in
                guard let identifier = encounter.notificationIdentifier,
                      replacingRequestIdentifiers.contains(identifier),
                      encounter.presentedAt == nil,
                      encounter.openedAt == nil,
                      encounter.scheduledAt > date
                else {
                    return nil
                }
                modelContext.delete(encounter)
                return encounter.commitmentID
            }
        )

        for (commitmentID, reminders) in remindersByCommitment {
            for reminder in reminders {
                modelContext.insert(
                    ReminderEncounter(
                        id: reminder.encounterID,
                        commitmentID: commitmentID,
                        scheduledAt: reminder.date,
                        notificationIdentifier: reminder.requestIdentifier
                    )
                )
            }
            commitments.first(where: { $0.id == commitmentID })?.nextReminderAt = reminders
                .map(\.date)
                .min()
        }

        for commitmentID in replacedCommitmentIDs.subtracting(remindersByCommitment.keys) {
            commitments.first(where: { $0.id == commitmentID })?.nextReminderAt = nil
        }
        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func saveNotificationSlot(_ draft: NotificationDaySlotDraft) -> Bool {
        replaceNotificationSlots(
            replacingRequestIdentifiers: [draft.requestIdentifier],
            with: [draft]
        )
    }

    @discardableResult
    func replaceNotificationSlots(
        replacingRequestIdentifiers: Set<String>,
        with drafts: [NotificationDaySlotDraft]
    ) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }

        let dayKeys = drafts.map(\.dayKey)
        let requestIdentifiers = drafts.map(\.requestIdentifier)
        guard Set(dayKeys).count == dayKeys.count,
              Set(requestIdentifiers).count == requestIdentifiers.count
        else {
            return false
        }

        let replacingSlots = notificationSlots.filter {
            replacingRequestIdentifiers.contains($0.requestIdentifier)
        }
        guard replacingSlots.allSatisfy({ $0.consumedAt == nil }) else {
            return false
        }

        let replacingSlotIDs = Set(replacingSlots.map(\.id))
        let protectedDayKeys = Set(
            notificationSlots
                .filter { !replacingSlotIDs.contains($0.id) }
                .map(\.dayKey)
        )
        guard protectedDayKeys.isDisjoint(with: dayKeys) else {
            return false
        }

        var reusableSlotsByDay = Dictionary(
            uniqueKeysWithValues: replacingSlots.map { ($0.dayKey, $0) }
        )

        for draft in drafts {
            if let slot = reusableSlotsByDay.removeValue(forKey: draft.dayKey) {
                apply(draft, to: slot)
            } else {
                modelContext.insert(makeNotificationSlot(from: draft))
            }
        }

        reusableSlotsByDay.values.forEach(modelContext.delete)
        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func markNotificationSlotConsumed(
        requestIdentifier: String,
        at date: Date = .now
    ) -> Bool {
        guard let slot = notificationSlot(requestIdentifier: requestIdentifier) else {
            return false
        }
        slot.consumedAt = slot.consumedAt ?? date
        return saveChanges()
    }

    @discardableResult
    func removeUnconsumedNotificationSlot(
        id: UUID,
        requestIdentifier: String
    ) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }
        guard refreshPersistentState() else { return false }
        guard let slot = notificationSlots.first(where: {
            $0.id == id && $0.requestIdentifier == requestIdentifier
        }) else {
            return true
        }
        guard slot.consumedAt == nil else { return false }

        modelContext.delete(slot)
        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func removeNotificationSlots(
        requestIdentifiers: Set<String>,
        at date: Date = .now
    ) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }

        let removableSlots = notificationSlots.filter {
            requestIdentifiers.contains($0.requestIdentifier)
                && $0.consumedAt == nil
                && $0.scheduledAt > date
        }
        removableSlots.forEach(modelContext.delete)
        guard !removableSlots.isEmpty else { return true }
        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func removeFutureReminderState(
        commitmentIDs: Set<UUID>,
        at date: Date = .now
    ) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }

        notificationSlots
            .filter {
                $0.sourceStorage == WhisperNotificationSource.commitment.rawValue
                    && ($0.commitmentID.map(commitmentIDs.contains) ?? false)
                    && $0.consumedAt == nil
                    && $0.scheduledAt > date
            }
            .forEach(modelContext.delete)
        encounters
            .filter {
                commitmentIDs.contains($0.commitmentID)
                    && $0.presentedAt == nil
                    && $0.openedAt == nil
                    && $0.scheduledAt > date
            }
            .forEach(modelContext.delete)
        commitments
            .filter { commitmentIDs.contains($0.id) }
            .forEach { $0.nextReminderAt = nil }
        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func restoreNextReminderFromScheduledEncounters(commitmentID: UUID) -> Bool {
        guard let commitment = commitments.first(where: { $0.id == commitmentID }) else {
            return false
        }

        commitment.nextReminderAt = encounters
            .filter {
                $0.commitmentID == commitmentID
                    && $0.notificationIdentifier != nil
                    && $0.presentedAt == nil
                    && $0.openedAt == nil
            }
            .map(\.scheduledAt)
            .min()
        return saveChanges()
    }

    func pausedReminderPlan(for commitmentID: UUID) -> CommitmentReminderPlan? {
        guard let commitment = commitments.first(where: { $0.id == commitmentID }),
              commitment.lifecycleStatus() == .paused,
              let pausedUntil = commitment.pausedUntil
        else {
            return nil
        }

        return makePlan(for: commitment, reminderDates: [pausedUntil])
    }

    @discardableResult
    func forgetCommitment(_ commitment: WhisperCommitment) -> Bool {
        guard commitment.lifecycleStatus() != .released else { return false }
        commitment.isActive = false
        commitment.nextReminderAt = nil
        commitment.pausedUntil = nil
        commitment.releasedAt = .now
        return saveChanges()
    }

    @discardableResult
    func pauseCommitment(_ commitmentID: UUID, until date: Date) -> Bool {
        guard date > .now,
              let commitment = commitments.first(where: { $0.id == commitmentID }),
              commitment.lifecycleStatus() == .active
        else { return false }

        commitment.pausedUntil = date
        commitment.nextReminderAt = nil
        return saveChanges()
    }

    func encounters(for commitmentID: UUID) -> [ReminderEncounter] {
        encounters.filter { $0.commitmentID == commitmentID }
    }

    @discardableResult
    func addEncounter(
        id: UUID = UUID(),
        commitmentID: UUID,
        scheduledAt: Date,
        notificationIdentifier: String? = nil
    ) -> ReminderEncounter? {
        guard let modelContext,
              commitments.contains(where: { $0.id == commitmentID })
        else {
            if modelContext == nil {
                setUnavailablePersistenceError()
            }
            return nil
        }

        let encounter = ReminderEncounter(
            id: id,
            commitmentID: commitmentID,
            scheduledAt: scheduledAt,
            notificationIdentifier: notificationIdentifier
        )
        modelContext.insert(encounter)
        guard saveChanges(reloadAfterSave: true) else { return nil }
        return encounters.first { $0.id == encounter.id }
    }

#if DEBUG
    func futureDebugReminderRequestIdentifiers(
        at date: Date = .now
    ) -> Set<String> {
        Set(encounters.compactMap { encounter in
            guard let identifier = encounter.notificationIdentifier,
                  identifier.hasPrefix(CommitmentReminderScheduler.debugRequestPrefix),
                  encounter.presentedAt == nil,
                  encounter.openedAt == nil,
                  encounter.scheduledAt > date
            else {
                return nil
            }
            return identifier
        })
    }

    @discardableResult
    func removeFutureDebugReminderState(
        requestIdentifiers: Set<String>,
        at date: Date = .now
    ) -> Bool {
        guard !requestIdentifiers.isEmpty else { return true }
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }

        notificationSlots
            .filter {
                requestIdentifiers.contains($0.requestIdentifier)
                    && $0.consumedAt == nil
                    && $0.scheduledAt > date
            }
            .forEach(modelContext.delete)
        encounters
            .filter {
                guard let identifier = $0.notificationIdentifier else { return false }
                return requestIdentifiers.contains(identifier)
                    && $0.presentedAt == nil
                    && $0.openedAt == nil
                    && $0.scheduledAt > date
            }
            .forEach(modelContext.delete)
        return saveChanges(reloadAfterSave: true)
    }
#endif

    @discardableResult
    func replaceScheduledEncounters(
        commitmentID: UUID,
        reminders: [ScheduledCommitmentReminder]
    ) -> Bool {
        guard let modelContext,
              let commitment = commitments.first(where: { $0.id == commitmentID })
        else {
            if modelContext == nil {
                setUnavailablePersistenceError()
            }
            return false
        }

        encounters
            .filter {
                $0.commitmentID == commitmentID
                    && $0.presentedAt == nil
                    && $0.openedAt == nil
            }
            .forEach(modelContext.delete)

        for reminder in reminders {
            modelContext.insert(
                ReminderEncounter(
                    id: reminder.encounterID,
                    commitmentID: commitmentID,
                    scheduledAt: reminder.date,
                    notificationIdentifier: reminder.requestIdentifier
                )
            )
        }
        commitment.nextReminderAt = reminders.map(\.date).min()
        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func clearScheduledEncounters(commitmentID: UUID) -> Bool {
        guard let modelContext,
              let commitment = commitments.first(where: { $0.id == commitmentID })
        else {
            if modelContext == nil {
                setUnavailablePersistenceError()
            }
            return false
        }

        encounters
            .filter {
                $0.commitmentID == commitmentID
                    && $0.presentedAt == nil
                    && $0.openedAt == nil
            }
            .forEach(modelContext.delete)
        commitment.nextReminderAt = nil
        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func reconcileReminderNotifications(
        with state: CommitmentNotificationState,
        at date: Date = .now
    ) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }

        let trackedEncounters = encounters.filter { $0.notificationIdentifier != nil }
        let affectedCommitmentIDs = Set(trackedEncounters.map(\.commitmentID))

        for encounter in trackedEncounters {
            guard let identifier = encounter.notificationIdentifier else { continue }

            if let deliveredAt = state.deliveredEncounterDates[encounter.id] {
                encounter.presentedAt = encounter.presentedAt ?? deliveredAt
                consumeNotificationSlot(requestIdentifier: identifier, at: deliveredAt)
                if let commitment = commitments.first(where: { $0.id == encounter.commitmentID }) {
                    commitment.lastEncounteredAt = [
                        commitment.lastEncounteredAt,
                        encounter.presentedAt
                    ]
                    .compactMap { $0 }
                    .max()
                }
            } else if state.pendingRequestIdentifiers.contains(identifier) {
                continue
            } else if encounter.scheduledAt <= date {
                // 알림 센터에서 이미 지워졌더라도 예정 시각이 지났다면 한 번 노출된 것으로 보존해요.
                encounter.presentedAt = encounter.presentedAt ?? encounter.scheduledAt
                consumeNotificationSlot(
                    requestIdentifier: identifier,
                    at: encounter.scheduledAt
                )
                if let commitment = commitments.first(where: { $0.id == encounter.commitmentID }) {
                    commitment.lastEncounteredAt = [
                        commitment.lastEncounteredAt,
                        encounter.presentedAt
                    ]
                    .compactMap { $0 }
                    .max()
                }
            } else if encounter.openedAt == nil {
                // 미래 알림인데 시스템 예약에서 사라진 경우 고아 일정을 정리해요.
                modelContext.delete(encounter)
            }
        }

        let staleFutureSlotIDs = notificationSlots.compactMap { slot -> UUID? in
            guard slot.sourceStorage == WhisperNotificationSource.commitment.rawValue,
                  slot.consumedAt == nil,
                  slot.scheduledAt > date,
                  !state.pendingRequestIdentifiers.contains(slot.requestIdentifier)
            else {
                return nil
            }
            return slot.id
        }
        notificationSlots
            .filter { staleFutureSlotIDs.contains($0.id) }
            .forEach(modelContext.delete)

        for commitmentID in affectedCommitmentIDs {
            guard let commitment = commitments.first(where: { $0.id == commitmentID }) else {
                continue
            }
            commitment.nextReminderAt = trackedEncounters
                .filter {
                    $0.commitmentID == commitmentID
                        && $0.openedAt == nil
                        && (
                            $0.presentedAt != nil
                                || ($0.notificationIdentifier.map {
                                    state.pendingRequestIdentifiers.contains($0)
                                } ?? false)
                        )
                }
                .map(\.scheduledAt)
                .min()
        }

        return saveChanges(reloadAfterSave: true)
    }

    @discardableResult
    func markEncounterPresented(_ encounterID: UUID, at date: Date = .now) -> Bool {
        guard let encounter = encounters.first(where: { $0.id == encounterID }) else {
            return false
        }
        encounter.presentedAt = encounter.presentedAt ?? date
        consumeNotificationSlot(for: encounter, at: date)
        if let commitment = commitments.first(where: { $0.id == encounter.commitmentID }) {
            commitment.lastEncounteredAt = date
        }
        return saveChanges()
    }

    @discardableResult
    func markEncounterOpened(_ encounterID: UUID, at date: Date = .now) -> Bool {
        guard let encounter = encounters.first(where: { $0.id == encounterID }) else {
            return false
        }
        markEncounterOpenedState(encounter, at: date)
        return saveChanges()
    }

    @discardableResult
    func react(
        to encounterID: UUID,
        with reaction: ReminderEncounterReaction,
        pausedUntil requestedPausedUntil: Date? = nil,
        at date: Date = .now
    ) -> Bool {
        guard let encounter = encounters.first(where: { $0.id == encounterID }),
              let commitment = commitments.first(where: { $0.id == encounter.commitmentID }),
              commitment.lifecycleStatus(at: date) == .active
        else {
            return false
        }

        encounter.reaction = reaction
        markEncounterOpenedState(encounter, commitment: commitment, at: date)

        switch reaction {
        case .keep:
            commitment.isActive = true
            commitment.pausedUntil = nil
            commitment.releasedAt = nil
        case .pause:
            commitment.isActive = true
            commitment.pausedUntil = requestedPausedUntil
                ?? Calendar.current.date(byAdding: .day, value: 30, to: date)
            commitment.nextReminderAt = nil
        case .release:
            commitment.isActive = false
            commitment.pausedUntil = nil
            commitment.releasedAt = date
            commitment.nextReminderAt = nil

            guard let modelContext else {
                setUnavailablePersistenceError()
                return false
            }
            notificationSlots
                .filter {
                    $0.sourceStorage == WhisperNotificationSource.commitment.rawValue
                        && $0.commitmentID == commitment.id
                        && $0.consumedAt == nil
                        && $0.scheduledAt > date
                }
                .forEach(modelContext.delete)
            encounters
                .filter {
                    $0.commitmentID == commitment.id
                        && $0.presentedAt == nil
                        && $0.openedAt == nil
                        && $0.scheduledAt > date
                }
                .forEach(modelContext.delete)
        }

        return saveChanges(reloadAfterSave: reaction == .release)
    }

    func recordCount(inWeekOf date: Date = .now, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        let recordedDays = records
            .filter { interval.contains($0.createdAt) }
            .map { calendar.startOfDay(for: $0.createdAt) }
        return Set(recordedDays).count
    }

    func hasRecord(on date: Date, calendar: Calendar = .current) -> Bool {
        records.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    func records(on date: Date, calendar: Calendar = .current) -> [WhisperRecord] {
        records.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    func records(linkedTo focusMode: String) -> [WhisperRecord] {
        records.filter { $0.focusMode == focusMode }
    }

    func record(withID id: UUID) -> WhisperRecord? {
        records.first { $0.id == id }
    }

    @discardableResult
    func setFocusMode(_ focusMode: String?, for record: WhisperRecord) -> Bool {
        record.focusMode = focusMode
        record.updatedAt = .now
        return saveChanges()
    }

    func resurfacingRecord(
        on date: Date = .now,
        minimumAgeInDays: Int = 30,
        calendar: Calendar = .current
    ) -> WhisperRecord? {
        let candidates = records
            .filter {
                daysSince($0, relativeTo: date, calendar: calendar) >= minimumAgeInDays
            }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.createdAt < $1.createdAt
            }

        guard !candidates.isEmpty else { return nil }

        let dayOrdinal = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return candidates[dayOrdinal % candidates.count]
    }

    func daysSince(
        _ record: WhisperRecord,
        relativeTo date: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let recordDay = calendar.startOfDay(for: record.createdAt)
        let referenceDay = calendar.startOfDay(for: date)
        return max(
            0,
            calendar.dateComponents([.day], from: recordDay, to: referenceDay).day ?? 0
        )
    }

    @discardableResult
    func refreshPersistentState() -> Bool {
        reload()
        return isPersistenceAvailable
    }

    private func saveChanges(reloadAfterSave: Bool = false) -> Bool {
        guard let modelContext else {
            setUnavailablePersistenceError()
            return false
        }
        do {
            try modelContext.save()
            clearPersistenceIssue()
            if reloadAfterSave {
                reload()
            }
            return true
        } catch {
            modelContext.rollback()
            reload()
            recordPersistenceError(error, operation: "model-context-save")
            return false
        }
    }

    private func reload() {
        guard let modelContext else {
            clearCachedModels()
            setUnavailablePersistenceError()
            return
        }
        let descriptor = FetchDescriptor<WhisperRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            records = try modelContext.fetch(descriptor)
            commitments = try modelContext.fetch(
                FetchDescriptor<WhisperCommitment>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            )
            encounters = try modelContext.fetch(
                FetchDescriptor<ReminderEncounter>(
                    sortBy: [SortDescriptor(\.scheduledAt, order: .reverse)]
                )
            )
            notificationSlots = try modelContext.fetch(
                FetchDescriptor<NotificationDaySlot>(
                    sortBy: [SortDescriptor(\.scheduledAt)]
                )
            )
            journals = try modelContext.fetch(
                FetchDescriptor<DailyJournal>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
            )
            clearPersistenceIssue()
        } catch {
            clearCachedModels()
            isPersistenceAvailable = false
            recordPersistenceError(error, operation: "model-context-fetch")
        }
    }

    private func activeCommitment(
        withID id: UUID,
        at date: Date
    ) -> WhisperCommitment? {
        commitments.first {
            $0.id == id && $0.lifecycleStatus(at: date) == .active
        }
    }

    private func makeSnapshot(from commitment: WhisperCommitment) -> CommitmentSnapshot {
        CommitmentSnapshot(
            id: commitment.id,
            name: commitment.name,
            quote: commitment.quote,
            topics: commitment.topics,
            createdAt: commitment.createdAt,
            lastContinuedAt: commitment.lastContinuedAt,
            continuationCount: commitment.continuationCount
        )
    }

    private func makePlan(
        for commitment: WhisperCommitment,
        reminderDates: [Date]
    ) -> CommitmentReminderPlan {
        CommitmentReminderPlan(
            id: commitment.id,
            sourceRecordID: commitment.sourceRecordID,
            name: commitment.name,
            quote: commitment.quote,
            reminderDates: reminderDates
        )
    }

    private func consumeNotificationSlot(
        requestIdentifier: String,
        at date: Date
    ) {
        guard let slot = notificationSlot(requestIdentifier: requestIdentifier) else { return }
        slot.consumedAt = slot.consumedAt ?? date
    }

    private func consumeNotificationSlot(
        for encounter: ReminderEncounter,
        at date: Date
    ) {
        guard let identifier = encounter.notificationIdentifier else { return }
        consumeNotificationSlot(requestIdentifier: identifier, at: date)
    }

    private func markEncounterOpenedState(
        _ encounter: ReminderEncounter,
        commitment providedCommitment: WhisperCommitment? = nil,
        at date: Date
    ) {
        let wasUnread = encounter.openedAt == nil
        encounter.openedAt = encounter.openedAt ?? date
        encounter.presentedAt = encounter.presentedAt ?? date
        consumeNotificationSlot(for: encounter, at: date)

        guard let commitment = providedCommitment
            ?? commitments.first(where: { $0.id == encounter.commitmentID })
        else {
            return
        }
        commitment.lastEncounteredAt = encounter.presentedAt
        commitment.lastReadAt = encounter.openedAt
        if wasUnread {
            commitment.encounterCount += 1
        }
    }

    private func clearCachedModels() {
        records = []
        commitments = []
        encounters = []
        notificationSlots = []
        journals = []
    }

    private func clearPersistenceIssue() {
        persistenceError = nil
        persistenceSupportCode = nil
        persistenceDiagnosticSummary = nil
        isPersistenceAvailable = true
    }

    private func reminderPlan(
        for commitment: WhisperCommitment,
        anchorDate: Date,
        timing: CommitmentReminderTiming,
        firstReminderDate: Date? = nil
    ) -> CommitmentReminderPlan {
        makePlan(
            for: commitment,
            reminderDates: makeReminderDates(
                anchorDate: anchorDate,
                timing: timing,
                firstReminderDate: firstReminderDate
            )
        )
    }

    private func policyReminderPlan(
        for commitment: WhisperCommitment,
        event: CommitmentReminderPolicyEvent,
        firstReminderDate: Date? = nil,
        now: Date
    ) -> CommitmentReminderPlan {
        let nextDate = firstReminderDate ?? CommitmentReminderPolicy.nextReminderDate(
            profile: commitment.reminderProfile,
            behavior: reminderBehaviorSummary(for: commitment.id, at: now),
            event: event,
            now: now
        )
        return makePlan(for: commitment, reminderDates: [nextDate])
    }

    private func hasFutureScheduledEncounter(
        for commitmentID: UUID,
        at date: Date
    ) -> Bool {
        encounters.contains { encounter in
            encounter.commitmentID == commitmentID
                && encounter.notificationIdentifier != nil
                && encounter.presentedAt == nil
                && encounter.openedAt == nil
                && encounter.scheduledAt > date
        }
    }

    private func makeReminderDates(
        anchorDate: Date,
        timing: CommitmentReminderTiming,
        firstReminderDate: Date? = nil
    ) -> [Date] {
        let suggestedDates = timing.offsetsInHours.map {
            anchorDate.addingTimeInterval(TimeInterval($0 * 60 * 60))
        }

        guard let firstReminderDate else { return suggestedDates }
        let laterSuggestedDates = suggestedDates.filter {
            $0 > firstReminderDate.addingTimeInterval(60)
        }
        return [firstReminderDate] + (
            laterSuggestedDates.isEmpty
                ? [firstReminderDate.addingTimeInterval(72 * 60 * 60)]
                : laterSuggestedDates
        )
    }

    private func makeNotificationSlot(
        from draft: NotificationDaySlotDraft
    ) -> NotificationDaySlot {
        NotificationDaySlot(
            dayKey: draft.dayKey,
            scheduledAt: draft.scheduledAt,
            requestIdentifier: draft.requestIdentifier,
            sourceStorage: draft.sourceStorage,
            commitmentID: draft.commitmentID,
            recordID: draft.recordID,
            consumedAt: draft.consumedAt,
            createdAt: draft.createdAt
        )
    }

    private func apply(
        _ draft: NotificationDaySlotDraft,
        to slot: NotificationDaySlot
    ) {
        slot.dayKey = draft.dayKey
        slot.scheduledAt = draft.scheduledAt
        slot.requestIdentifier = draft.requestIdentifier
        slot.sourceStorage = draft.sourceStorage
        slot.commitmentID = draft.commitmentID
        slot.recordID = draft.recordID
        slot.consumedAt = draft.consumedAt
        slot.createdAt = draft.createdAt
    }

    private func migrateLegacyRecordsIfNeeded() {
        guard let modelContext,
              let data = UserDefaults.standard.data(forKey: legacyStorageKey)
        else {
            return
        }

        let legacyRecords: [LegacyWhisperRecord]
        do {
            legacyRecords = try JSONDecoder().decode([LegacyWhisperRecord].self, from: data)
        } catch {
            WhisperDiagnostics.logPersistenceError(
                error,
                operation: "legacy-user-defaults-decode"
            )
            return
        }

        let existingIDs = Set(records.map(\.id))
        let recordsToMigrate = legacyRecords.filter { !existingIDs.contains($0.id) }

        for record in recordsToMigrate {
            modelContext.insert(
                WhisperRecord(
                    id: record.id,
                    title: record.title,
                    content: record.content,
                    createdAt: record.createdAt
                )
            )
        }

        do {
            if !recordsToMigrate.isEmpty {
                try modelContext.save()
            }
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            reload()
        } catch {
            modelContext.rollback()
            recordPersistenceError(error, operation: "legacy-user-defaults-migration")
        }
    }

    private func recordPersistenceError(_ error: Error, operation: String) {
        WhisperDiagnostics.logPersistenceError(error, operation: operation)
        persistenceError = error.localizedDescription
        persistenceSupportCode = WhisperDiagnostics.persistenceSupportCode(for: error)
        persistenceDiagnosticSummary = WhisperDiagnostics.persistenceSummary(
            for: error,
            operation: operation
        )
    }

    private func setUnavailablePersistenceError() {
        isPersistenceAvailable = false
        if persistenceError == nil {
            persistenceError = "기록 저장소를 사용할 수 없어요."
            persistenceSupportCode = "WSP-STORAGE-UNAVAILABLE"
            persistenceDiagnosticSummary = [
                "Whisper 저장소를 사용할 수 없음",
                "지원 코드: WSP-STORAGE-UNAVAILABLE"
            ].joined(separator: "\n")
        }
    }
}
