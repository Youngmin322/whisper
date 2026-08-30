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

enum WhisperMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            WhisperLegacyEmberSchema.self,
            WhisperLegacyBridgeSchema.self,
            WhisperSchemaV1.self,
            WhisperSchemaV2.self
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
            )
        ]
    }
}

typealias WhisperRecord = WhisperSchemaV2.WhisperRecord
typealias WhisperCommitment = WhisperSchemaV2.WhisperCommitment
typealias ReminderEncounter = WhisperSchemaV2.ReminderEncounter
