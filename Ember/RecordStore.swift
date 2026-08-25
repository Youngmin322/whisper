//
//  RecordStore.swift
//  Ember
//

import Foundation
import Observation
import SwiftData

@Model
final class EmberRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var focusMode: String?
    var emotion: String?
    @Attribute(.externalStorage) var photoData: Data?

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        focusMode: String? = nil,
        emotion: String? = nil,
        photoData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.focusMode = focusMode
        self.emotion = emotion
        self.photoData = photoData
    }
}

@Model
final class EmberCommitment {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var sourceRecordID: UUID
    var name: String
    var quote: String
    var topicsStorage: String
    var createdAt: Date
    var lastContinuedAt: Date?
    var nextReminderAt: Date?
    var continuationCount: Int
    var isActive: Bool

    init(
        id: UUID = UUID(),
        sourceRecordID: UUID,
        name: String,
        quote: String,
        topics: [String],
        createdAt: Date = .now,
        lastContinuedAt: Date? = nil,
        nextReminderAt: Date? = nil,
        continuationCount: Int = 0,
        isActive: Bool = true
    ) {
        self.id = id
        self.sourceRecordID = sourceRecordID
        self.name = name
        self.quote = quote
        topicsStorage = topics.joined(separator: "\u{001F}")
        self.createdAt = createdAt
        self.lastContinuedAt = lastContinuedAt
        self.nextReminderAt = nextReminderAt
        self.continuationCount = continuationCount
        self.isActive = isActive
    }

    var topics: [String] {
        topicsStorage
            .split(separator: "\u{001F}")
            .map(String.init)
    }
}

struct CommitmentSnapshot: Sendable {
    let id: UUID
    let name: String
    let quote: String
    let topics: [String]
}

struct CommitmentReminderPlan: Sendable {
    let id: UUID
    let sourceRecordID: UUID
    let name: String
    let quote: String
    let anchorDate: Date
    let dayOffsets: [Int]
}

private struct LegacyEmberRecord: Codable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: Date
}

@MainActor
@Observable
final class RecordStore {
    private(set) var records: [EmberRecord] = []
    private(set) var commitments: [EmberCommitment] = []
    private(set) var persistenceError: String?

    @ObservationIgnored private let modelContainer: ModelContainer
    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let legacyStorageKey = "ember.records"

    init(isStoredInMemoryOnly: Bool = false) {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        do {
            modelContainer = try ModelContainer(
                for: EmberRecord.self,
                EmberCommitment.self,
                configurations: configuration
            )
        } catch {
            fatalError("SwiftData 저장소를 만들 수 없습니다: \(error.localizedDescription)")
        }

        modelContext = modelContainer.mainContext
        reload()

        if !isStoredInMemoryOnly {
            migrateLegacyRecordsIfNeeded()
        }
    }

    var latestRecord: EmberRecord? {
        records.first
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
    ) -> EmberRecord? {
        let record = EmberRecord(
            title: title,
            content: content,
            createdAt: createdAt,
            focusMode: focusMode,
            emotion: emotion,
            photoData: photoData
        )
        modelContext.insert(record)
        guard saveChanges() else { return nil }
        return self.record(withID: record.id)
    }

    @discardableResult
    func update(
        _ record: EmberRecord,
        title: String,
        content: String,
        emotion: String?,
        photoData: Data?
    ) -> Bool {
        record.title = title
        record.content = content
        record.emotion = emotion
        record.photoData = photoData
        record.updatedAt = .now
        return saveChanges()
    }

    @discardableResult
    func delete(_ record: EmberRecord) -> Bool {
        let relatedCommitments = commitments.filter { $0.sourceRecordID == record.id }
        let commitmentIDs = relatedCommitments.map(\.id)
        relatedCommitments.forEach(modelContext.delete)
        modelContext.delete(record)
        let didSave = saveChanges()

        if didSave {
            Task {
                await CommitmentReminderScheduler.cancel(commitmentIDs: commitmentIDs)
            }
        }

        return didSave
    }

    var activeCommitmentSnapshots: [CommitmentSnapshot] {
        commitments
            .filter(\.isActive)
            .prefix(8)
            .map {
                CommitmentSnapshot(
                    id: $0.id,
                    name: $0.name,
                    quote: $0.quote,
                    topics: $0.topics
                )
            }
    }

    func commitment(sourceRecordID: UUID) -> EmberCommitment? {
        commitments.first { $0.sourceRecordID == sourceRecordID && $0.isActive }
    }

    @discardableResult
    func rememberCommitment(
        sourceRecordID: UUID,
        name: String,
        quote: String,
        topics: [String],
        now: Date = .now
    ) -> CommitmentReminderPlan? {
        if let existing = commitment(sourceRecordID: sourceRecordID) {
            return reminderPlan(for: existing, anchorDate: now, dayOffsets: [7, 21, 60])
        }

        let commitment = EmberCommitment(
            sourceRecordID: sourceRecordID,
            name: name,
            quote: quote,
            topics: topics,
            createdAt: now,
            nextReminderAt: Calendar.current.date(byAdding: .day, value: 7, to: now)
        )
        modelContext.insert(commitment)

        guard saveChanges(),
              let saved = self.commitment(sourceRecordID: sourceRecordID)
        else {
            return nil
        }

        return reminderPlan(for: saved, anchorDate: now, dayOffsets: [7, 21, 60])
    }

    func continueCommitment(_ id: UUID, now: Date = .now) -> CommitmentReminderPlan? {
        guard let commitment = commitments.first(where: { $0.id == id && $0.isActive }) else {
            return nil
        }

        commitment.lastContinuedAt = now
        commitment.continuationCount += 1
        commitment.nextReminderAt = Calendar.current.date(byAdding: .day, value: 14, to: now)

        guard saveChanges(),
              let saved = commitments.first(where: { $0.id == id })
        else {
            return nil
        }

        return reminderPlan(for: saved, anchorDate: now, dayOffsets: [14, 35, 90])
    }

    @discardableResult
    func forgetCommitment(_ commitment: EmberCommitment) -> Bool {
        commitment.isActive = false
        commitment.nextReminderAt = nil
        let commitmentID = commitment.id
        let didSave = saveChanges()

        if didSave {
            Task {
                await CommitmentReminderScheduler.cancel(commitmentIDs: [commitmentID])
            }
        }

        return didSave
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

    func records(on date: Date, calendar: Calendar = .current) -> [EmberRecord] {
        records.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
    }

    func records(linkedTo focusMode: String) -> [EmberRecord] {
        records.filter { $0.focusMode == focusMode }
    }

    func record(withID id: UUID) -> EmberRecord? {
        records.first { $0.id == id }
    }

    @discardableResult
    func setFocusMode(_ focusMode: String?, for record: EmberRecord) -> Bool {
        record.focusMode = focusMode
        record.updatedAt = .now
        return saveChanges()
    }

    func resurfacingRecord(
        on date: Date = .now,
        minimumAgeInDays: Int = 30,
        calendar: Calendar = .current
    ) -> EmberRecord? {
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
        _ record: EmberRecord,
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

    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            reload()
            return true
        } catch {
            let errorMessage = error.localizedDescription
            modelContext.rollback()
            reload()
            persistenceError = errorMessage
            return false
        }
    }

    private func reload() {
        let descriptor = FetchDescriptor<EmberRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            records = try modelContext.fetch(descriptor)
            commitments = try modelContext.fetch(
                FetchDescriptor<EmberCommitment>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            )
            persistenceError = nil
        } catch {
            records = []
            commitments = []
            persistenceError = error.localizedDescription
        }
    }

    private func reminderPlan(
        for commitment: EmberCommitment,
        anchorDate: Date,
        dayOffsets: [Int]
    ) -> CommitmentReminderPlan {
        CommitmentReminderPlan(
            id: commitment.id,
            sourceRecordID: commitment.sourceRecordID,
            name: commitment.name,
            quote: commitment.quote,
            anchorDate: anchorDate,
            dayOffsets: dayOffsets
        )
    }

    private func migrateLegacyRecordsIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: legacyStorageKey),
              let legacyRecords = try? JSONDecoder().decode([LegacyEmberRecord].self, from: data)
        else {
            return
        }

        let existingIDs = Set(records.map(\.id))
        let recordsToMigrate = legacyRecords.filter { !existingIDs.contains($0.id) }

        for record in recordsToMigrate {
            modelContext.insert(
                EmberRecord(
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
            persistenceError = error.localizedDescription
        }
    }
}
