//
//  WhisperSchema.swift
//  Whisper
//

import Foundation
import SwiftData

enum CommitmentLifecycleStatus: String, Sendable {
    case active
    case paused
    case released
}

enum ReminderEncounterReaction: String, CaseIterable, Sendable {
    case keep
    case pause
    case release
}

// Whisper 1.0 was shipped after the app bundle had been renamed from Ember,
// but before the SwiftData model types were renamed. Keep this schema frozen so
// those on-device stores remain recognizable by the staged migration manager.
enum WhisperLegacyEmberSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(0, 0, 0)

    static var models: [any PersistentModel.Type] {
        [EmberRecord.self, EmberCommitment.self]
    }

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
    }
}

enum WhisperSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [WhisperRecord.self, WhisperCommitment.self]
    }

    @Model
    final class WhisperRecord {
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
    final class WhisperCommitment {
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
    }
}

// This schema is used only while migrating. It lets the migration context read
// the 1.0 Ember entities and insert their Whisper equivalents in one store.
enum WhisperLegacyBridgeSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(0, 5, 0)

    static var models: [any PersistentModel.Type] {
        [
            WhisperLegacyEmberSchema.EmberRecord.self,
            WhisperLegacyEmberSchema.EmberCommitment.self,
            WhisperSchemaV1.WhisperRecord.self,
            WhisperSchemaV1.WhisperCommitment.self
        ]
    }
}

enum WhisperSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [WhisperRecord.self, WhisperCommitment.self, ReminderEncounter.self]
    }

    @Model
    final class WhisperRecord {
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
    final class WhisperCommitment {
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
        var pausedUntil: Date?
        var releasedAt: Date?
        var lastEncounteredAt: Date?
        var lastReadAt: Date?
        var encounterCount: Int = 0

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
            isActive: Bool = true,
            pausedUntil: Date? = nil,
            releasedAt: Date? = nil,
            lastEncounteredAt: Date? = nil,
            lastReadAt: Date? = nil,
            encounterCount: Int = 0
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
            self.pausedUntil = pausedUntil
            self.releasedAt = releasedAt
            self.lastEncounteredAt = lastEncounteredAt
            self.lastReadAt = lastReadAt
            self.encounterCount = encounterCount
        }

        var topics: [String] {
            topicsStorage
                .split(separator: "\u{001F}")
                .map(String.init)
        }

        func lifecycleStatus(at date: Date = .now) -> CommitmentLifecycleStatus {
            if !isActive || releasedAt != nil {
                return .released
            }
            if let pausedUntil, pausedUntil > date {
                return .paused
            }
            return .active
        }
    }

    @Model
    final class ReminderEncounter {
        @Attribute(.unique) var id: UUID
        var commitmentID: UUID
        var scheduledAt: Date
        var presentedAt: Date?
        var openedAt: Date?
        var reactionStorage: String?
        var notificationIdentifier: String?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            commitmentID: UUID,
            scheduledAt: Date,
            presentedAt: Date? = nil,
            openedAt: Date? = nil,
            reaction: ReminderEncounterReaction? = nil,
            notificationIdentifier: String? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.commitmentID = commitmentID
            self.scheduledAt = scheduledAt
            self.presentedAt = presentedAt
            self.openedAt = openedAt
            reactionStorage = reaction?.rawValue
            self.notificationIdentifier = notificationIdentifier
            self.createdAt = createdAt
        }

        var reaction: ReminderEncounterReaction? {
            get { reactionStorage.flatMap(ReminderEncounterReaction.init(rawValue:)) }
            set { reactionStorage = newValue?.rawValue }
        }
    }
}

enum WhisperSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WhisperRecord.self,
            WhisperCommitment.self,
            ReminderEncounter.self,
            NotificationDaySlot.self
        ]
    }

    @Model
    final class WhisperRecord {
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
    final class WhisperCommitment {
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
        var pausedUntil: Date?
        var releasedAt: Date?
        var lastEncounteredAt: Date?
        var lastReadAt: Date?
        var encounterCount: Int = 0

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
            isActive: Bool = true,
            pausedUntil: Date? = nil,
            releasedAt: Date? = nil,
            lastEncounteredAt: Date? = nil,
            lastReadAt: Date? = nil,
            encounterCount: Int = 0
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
            self.pausedUntil = pausedUntil
            self.releasedAt = releasedAt
            self.lastEncounteredAt = lastEncounteredAt
            self.lastReadAt = lastReadAt
            self.encounterCount = encounterCount
        }

        var topics: [String] {
            topicsStorage
                .split(separator: "\u{001F}")
                .map(String.init)
        }

        func lifecycleStatus(at date: Date = .now) -> CommitmentLifecycleStatus {
            if !isActive || releasedAt != nil {
                return .released
            }
            if let pausedUntil, pausedUntil > date {
                return .paused
            }
            return .active
        }
    }

    @Model
    final class ReminderEncounter {
        @Attribute(.unique) var id: UUID
        var commitmentID: UUID
        var scheduledAt: Date
        var presentedAt: Date?
        var openedAt: Date?
        var reactionStorage: String?
        var notificationIdentifier: String?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            commitmentID: UUID,
            scheduledAt: Date,
            presentedAt: Date? = nil,
            openedAt: Date? = nil,
            reaction: ReminderEncounterReaction? = nil,
            notificationIdentifier: String? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.commitmentID = commitmentID
            self.scheduledAt = scheduledAt
            self.presentedAt = presentedAt
            self.openedAt = openedAt
            reactionStorage = reaction?.rawValue
            self.notificationIdentifier = notificationIdentifier
            self.createdAt = createdAt
        }

        var reaction: ReminderEncounterReaction? {
            get { reactionStorage.flatMap(ReminderEncounterReaction.init(rawValue:)) }
            set { reactionStorage = newValue?.rawValue }
        }
    }

    @Model
    final class NotificationDaySlot {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var dayKey: String
        var scheduledAt: Date
        var requestIdentifier: String
        var sourceStorage: String
        var commitmentID: UUID?
        var recordID: UUID?
        var consumedAt: Date?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            dayKey: String,
            scheduledAt: Date,
            requestIdentifier: String,
            sourceStorage: String,
            commitmentID: UUID? = nil,
            recordID: UUID? = nil,
            consumedAt: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.dayKey = dayKey
            self.scheduledAt = scheduledAt
            self.requestIdentifier = requestIdentifier
            self.sourceStorage = sourceStorage
            self.commitmentID = commitmentID
            self.recordID = recordID
            self.consumedAt = consumedAt
            self.createdAt = createdAt
        }
    }
}

enum WhisperSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WhisperRecord.self,
            WhisperCommitment.self,
            ReminderEncounter.self,
            NotificationDaySlot.self
        ]
    }

    @Model
    final class WhisperRecord {
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
    final class WhisperCommitment {
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
        var pausedUntil: Date?
        var releasedAt: Date?
        var lastEncounteredAt: Date?
        var lastReadAt: Date?
        var encounterCount: Int = 0
        var reminderProfileData: Data?

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
            isActive: Bool = true,
            pausedUntil: Date? = nil,
            releasedAt: Date? = nil,
            lastEncounteredAt: Date? = nil,
            lastReadAt: Date? = nil,
            encounterCount: Int = 0,
            reminderProfile: CommitmentReminderProfile = .fallback
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
            self.pausedUntil = pausedUntil
            self.releasedAt = releasedAt
            self.lastEncounteredAt = lastEncounteredAt
            self.lastReadAt = lastReadAt
            self.encounterCount = encounterCount
            reminderProfileData = try? JSONEncoder().encode(reminderProfile)
        }

        var topics: [String] {
            topicsStorage
                .split(separator: "\u{001F}")
                .map(String.init)
        }

        var reminderProfile: CommitmentReminderProfile {
            get {
                guard let reminderProfileData,
                      let profile = try? JSONDecoder().decode(
                          CommitmentReminderProfile.self,
                          from: reminderProfileData
                      )
                else {
                    return .fallback
                }
                return profile
            }
            set {
                reminderProfileData = try? JSONEncoder().encode(newValue)
            }
        }

        func lifecycleStatus(at date: Date = .now) -> CommitmentLifecycleStatus {
            if !isActive || releasedAt != nil {
                return .released
            }
            if let pausedUntil, pausedUntil > date {
                return .paused
            }
            return .active
        }
    }

    @Model
    final class ReminderEncounter {
        @Attribute(.unique) var id: UUID
        var commitmentID: UUID
        var scheduledAt: Date
        var presentedAt: Date?
        var openedAt: Date?
        var reactionStorage: String?
        var notificationIdentifier: String?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            commitmentID: UUID,
            scheduledAt: Date,
            presentedAt: Date? = nil,
            openedAt: Date? = nil,
            reaction: ReminderEncounterReaction? = nil,
            notificationIdentifier: String? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.commitmentID = commitmentID
            self.scheduledAt = scheduledAt
            self.presentedAt = presentedAt
            self.openedAt = openedAt
            reactionStorage = reaction?.rawValue
            self.notificationIdentifier = notificationIdentifier
            self.createdAt = createdAt
        }

        var reaction: ReminderEncounterReaction? {
            get { reactionStorage.flatMap(ReminderEncounterReaction.init(rawValue:)) }
            set { reactionStorage = newValue?.rawValue }
        }
    }

    @Model
    final class NotificationDaySlot {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var dayKey: String
        var scheduledAt: Date
        var requestIdentifier: String
        var sourceStorage: String
        var commitmentID: UUID?
        var recordID: UUID?
        var consumedAt: Date?
        var createdAt: Date

        init(
            id: UUID = UUID(),
            dayKey: String,
            scheduledAt: Date,
            requestIdentifier: String,
            sourceStorage: String,
            commitmentID: UUID? = nil,
            recordID: UUID? = nil,
            consumedAt: Date? = nil,
            createdAt: Date = .now
        ) {
            self.id = id
            self.dayKey = dayKey
            self.scheduledAt = scheduledAt
            self.requestIdentifier = requestIdentifier
            self.sourceStorage = sourceStorage
            self.commitmentID = commitmentID
            self.recordID = recordID
            self.consumedAt = consumedAt
            self.createdAt = createdAt
        }
    }
}

enum WhisperSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WhisperSchemaV4.WhisperRecord.self,
            WhisperSchemaV4.WhisperCommitment.self,
            WhisperSchemaV4.ReminderEncounter.self,
            WhisperSchemaV4.NotificationDaySlot.self,
            DailyJournal.self
        ]
    }

    @Model
    final class DailyJournal {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var dayKey: String
        var date: Date
        var title: String
        var body: String
        var reflection: String
        var emotion: String?
        var sourceRecordIDsStorage: String
        var createdAt: Date
        var updatedAt: Date

        init(
            id: UUID = UUID(),
            dayKey: String,
            date: Date,
            title: String,
            body: String,
            reflection: String,
            emotion: String? = nil,
            sourceRecordIDs: [UUID],
            createdAt: Date = .now,
            updatedAt: Date? = nil
        ) {
            self.id = id
            self.dayKey = dayKey
            self.date = date
            self.title = title
            self.body = body
            self.reflection = reflection
            self.emotion = emotion
            sourceRecordIDsStorage = sourceRecordIDs.map(\.uuidString).joined(separator: "\u{001F}")
            self.createdAt = createdAt
            self.updatedAt = updatedAt ?? createdAt
        }

        var sourceRecordIDs: [UUID] {
            sourceRecordIDsStorage.split(separator: "\u{001F}")
                .compactMap { UUID(uuidString: String($0)) }
        }

        func update(title: String, body: String, sourceRecordIDs: [UUID], at date: Date = .now) {
            self.title = title
            self.body = body
            sourceRecordIDsStorage = sourceRecordIDs.map(\.uuidString).joined(separator: "\u{001F}")
            updatedAt = date
        }
    }
}

enum WhisperSchemaV6: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        WhisperSchemaV5.models + [WritingDraft.self]
    }

    @Model
    final class WritingDraft {
        @Attribute(.unique) var id: UUID
        @Attribute(.unique) var storageKey: String
        var payload: Data
        @Attribute(.externalStorage) var photoData: Data?
        var updatedAt: Date

        init(id: UUID, storageKey: String, payload: Data, photoData: Data? = nil) {
            self.id = id
            self.storageKey = storageKey
            self.payload = payload
            self.photoData = photoData
            updatedAt = .now
        }
    }
}

enum WhisperMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            WhisperLegacyEmberSchema.self,
            WhisperLegacyBridgeSchema.self,
            WhisperSchemaV1.self,
            WhisperSchemaV2.self,
            WhisperSchemaV3.self,
            WhisperSchemaV4.self,
            WhisperSchemaV5.self,
            WhisperSchemaV6.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: WhisperLegacyEmberSchema.self,
                toVersion: WhisperLegacyBridgeSchema.self
            ),
            .custom(
                fromVersion: WhisperLegacyBridgeSchema.self,
                toVersion: WhisperSchemaV1.self,
                willMigrate: { context in
                    let legacyRecords = try context.fetch(
                        FetchDescriptor<WhisperLegacyEmberSchema.EmberRecord>()
                    )
                    for record in legacyRecords {
                        context.insert(
                            WhisperSchemaV1.WhisperRecord(
                                id: record.id,
                                title: record.title,
                                content: record.content,
                                createdAt: record.createdAt,
                                updatedAt: record.updatedAt,
                                focusMode: record.focusMode,
                                emotion: record.emotion,
                                photoData: record.photoData
                            )
                        )
                    }

                    let legacyCommitments = try context.fetch(
                        FetchDescriptor<WhisperLegacyEmberSchema.EmberCommitment>()
                    )
                    for commitment in legacyCommitments {
                        context.insert(
                            WhisperSchemaV1.WhisperCommitment(
                                id: commitment.id,
                                sourceRecordID: commitment.sourceRecordID,
                                name: commitment.name,
                                quote: commitment.quote,
                                topics: commitment.topicsStorage
                                    .split(separator: "\u{001F}")
                                    .map(String.init),
                                createdAt: commitment.createdAt,
                                lastContinuedAt: commitment.lastContinuedAt,
                                nextReminderAt: commitment.nextReminderAt,
                                continuationCount: commitment.continuationCount,
                                isActive: commitment.isActive
                            )
                        )
                    }

                    try context.save()
                },
                didMigrate: nil
            ),
            .lightweight(
                fromVersion: WhisperSchemaV1.self,
                toVersion: WhisperSchemaV2.self
            ),
            .lightweight(
                fromVersion: WhisperSchemaV2.self,
                toVersion: WhisperSchemaV3.self
            ),
            .lightweight(
                fromVersion: WhisperSchemaV3.self,
                toVersion: WhisperSchemaV4.self
            ),
            .lightweight(
                fromVersion: WhisperSchemaV4.self,
                toVersion: WhisperSchemaV5.self
            ),
            .lightweight(
                fromVersion: WhisperSchemaV5.self,
                toVersion: WhisperSchemaV6.self
            )
        ]
    }
}

typealias WhisperRecord = WhisperSchemaV4.WhisperRecord
typealias WhisperCommitment = WhisperSchemaV4.WhisperCommitment
typealias ReminderEncounter = WhisperSchemaV4.ReminderEncounter
typealias NotificationDaySlot = WhisperSchemaV4.NotificationDaySlot
typealias DailyJournal = WhisperSchemaV5.DailyJournal
typealias WritingDraft = WhisperSchemaV6.WritingDraft
