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

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        focusMode: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.focusMode = focusMode
    }
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
        focusMode: String? = nil
    ) -> Bool {
        let record = EmberRecord(
            title: title,
            content: content,
            createdAt: createdAt,
            focusMode: focusMode
        )
        modelContext.insert(record)
        return saveChanges()
    }

    @discardableResult
    func update(_ record: EmberRecord, title: String, content: String) -> Bool {
        record.title = title
        record.content = content
        record.updatedAt = .now
        return saveChanges()
    }

    @discardableResult
    func delete(_ record: EmberRecord) -> Bool {
        modelContext.delete(record)
        return saveChanges()
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
            persistenceError = nil
        } catch {
            records = []
            persistenceError = error.localizedDescription
        }
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
