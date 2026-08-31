//
//  WhisperMigrationTests.swift
//  WhisperTests
//

import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("SwiftData 버전 마이그레이션", .serialized)
struct WhisperMigrationTests {
    @Test("1.0 Ember 스키마의 저장소 호환 형태를 고정한다")
    func legacyEmberSchemaFingerprintIsFrozen() {
        let schema = Schema(versionedSchema: WhisperLegacyEmberSchema.self)

        #expect(schema.version == Schema.Version(0, 0, 0))
        #expect(schemaFingerprint(schema) == [
            "EmberCommitment.createdAt:Foundation.Date:optional=false:unique=false",
            "EmberCommitment.continuationCount:Swift.Int:optional=false:unique=false",
            "EmberCommitment.id:Foundation.UUID:optional=false:unique=true",
            "EmberCommitment.isActive:Swift.Bool:optional=false:unique=false",
            "EmberCommitment.lastContinuedAt:Swift.Optional<Foundation.Date>:optional=true:unique=false",
            "EmberCommitment.name:Swift.String:optional=false:unique=false",
            "EmberCommitment.nextReminderAt:Swift.Optional<Foundation.Date>:optional=true:unique=false",
            "EmberCommitment.quote:Swift.String:optional=false:unique=false",
            "EmberCommitment.sourceRecordID:Foundation.UUID:optional=false:unique=true",
            "EmberCommitment.topicsStorage:Swift.String:optional=false:unique=false",
            "EmberRecord.content:Swift.String:optional=false:unique=false",
            "EmberRecord.createdAt:Foundation.Date:optional=false:unique=false",
            "EmberRecord.emotion:Swift.Optional<Swift.String>:optional=true:unique=false",
            "EmberRecord.focusMode:Swift.Optional<Swift.String>:optional=true:unique=false",
            "EmberRecord.id:Foundation.UUID:optional=false:unique=true",
            "EmberRecord.photoData:Swift.Optional<Foundation.Data>:optional=true:unique=false",
            "EmberRecord.title:Swift.String:optional=false:unique=false",
            "EmberRecord.updatedAt:Foundation.Date:optional=false:unique=false"
        ].sorted())
    }

    @Test("1.0 Ember 저장소의 기록과 결심을 현재 스키마로 보존한다")
    func migratesLegacyEmberStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "WhisperMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appending(path: "default.store")
        let recordID = UUID()
        let commitmentID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let updatedAt = createdAt.addingTimeInterval(600)
        let reminderAt = createdAt.addingTimeInterval(86_400)
        let photoData = Data([0x01, 0x02, 0x03])

        try makeLegacyStore(
            at: storeURL,
            recordID: recordID,
            commitmentID: commitmentID,
            createdAt: createdAt,
            updatedAt: updatedAt,
            reminderAt: reminderAt,
            photoData: photoData
        )

        let currentSchema = Schema(versionedSchema: WhisperSchemaV4.self)
        let configuration = ModelConfiguration(
            schema: currentSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: currentSchema,
            migrationPlan: WhisperMigrationPlan.self,
            configurations: configuration
        )
        let context = container.mainContext

        let records = try context.fetch(FetchDescriptor<WhisperRecord>())
        let commitments = try context.fetch(FetchDescriptor<WhisperCommitment>())
        let encounters = try context.fetch(FetchDescriptor<ReminderEncounter>())
        let notificationSlots = try context.fetch(FetchDescriptor<NotificationDaySlot>())

        let record = try #require(records.first)
        #expect(records.count == 1)
        #expect(record.id == recordID)
        #expect(record.title == "1.0 기록")
        #expect(record.content == "업데이트 뒤에도 남아야 하는 내용")
        #expect(record.createdAt == createdAt)
        #expect(record.updatedAt == updatedAt)
        #expect(record.focusMode == "집중")
        #expect(record.emotion == "평온")
        #expect(record.photoData == photoData)

        let commitment = try #require(commitments.first)
        #expect(commitments.count == 1)
        #expect(commitment.id == commitmentID)
        #expect(commitment.sourceRecordID == recordID)
        #expect(commitment.name == "매일 걷기")
        #expect(commitment.quote == "내일부터 매일 걷자")
        #expect(commitment.topics == ["건강", "산책"])
        #expect(commitment.createdAt == createdAt)
        #expect(commitment.nextReminderAt == reminderAt)
        #expect(commitment.continuationCount == 2)
        #expect(commitment.isActive)
        #expect(commitment.pausedUntil == nil)
        #expect(commitment.releasedAt == nil)
        #expect(commitment.encounterCount == 0)
        #expect(commitment.reminderProfile == .fallback)
        #expect(encounters.isEmpty)
        #expect(notificationSlots.isEmpty)
    }

    @Test("Whisper V1 저장소를 현재 스키마로 보존한다")
    func migratesWhisperV1Store() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        let recordID = UUID()
        let commitmentID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_800_100_000)

        try makeV1Store(
            at: storeURL,
            recordID: recordID,
            commitmentID: commitmentID,
            createdAt: createdAt
        )

        let container = try makeCurrentContainer(at: storeURL)
        let records = try container.mainContext.fetch(FetchDescriptor<WhisperRecord>())
        let commitments = try container.mainContext.fetch(FetchDescriptor<WhisperCommitment>())

        #expect(records.map(\.id) == [recordID])
        #expect(commitments.map(\.id) == [commitmentID])
        #expect(commitments.first?.sourceRecordID == recordID)
        #expect(commitments.first?.pausedUntil == nil)
    }

    @Test("Whisper V2 저장소를 V3로 옮길 때 기존 데이터는 보존하고 알림 슬롯은 비어 있다")
    func migratesWhisperV2Store() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        let recordID = UUID()
        let commitmentID = UUID()
        let encounterID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_800_200_000)
        let scheduledAt = createdAt.addingTimeInterval(86_400)

        try makeV2Store(
            at: storeURL,
            recordID: recordID,
            commitmentID: commitmentID,
            encounterID: encounterID,
            createdAt: createdAt,
            scheduledAt: scheduledAt
        )

        let container = try makeCurrentContainer(at: storeURL)
        let context = container.mainContext
        let records = try context.fetch(FetchDescriptor<WhisperRecord>())
        let commitments = try context.fetch(FetchDescriptor<WhisperCommitment>())
        let encounters = try context.fetch(FetchDescriptor<ReminderEncounter>())
        let notificationSlots = try context.fetch(FetchDescriptor<NotificationDaySlot>())

        let record = try #require(records.first)
        #expect(records.count == 1)
        #expect(record.id == recordID)
        #expect(record.title == "V2 기록")
        #expect(record.content == "V3에서도 보존할 내용")

        let commitment = try #require(commitments.first)
        #expect(commitments.count == 1)
        #expect(commitment.id == commitmentID)
        #expect(commitment.sourceRecordID == recordID)
        #expect(commitment.name == "V2 결심")
        #expect(commitment.nextReminderAt == scheduledAt)
        #expect(commitment.encounterCount == 3)

        let encounter = try #require(encounters.first)
        #expect(encounters.count == 1)
        #expect(encounter.id == encounterID)
        #expect(encounter.commitmentID == commitmentID)
        #expect(encounter.scheduledAt == scheduledAt)
        #expect(encounter.notificationIdentifier == "whisper.commitment.v2")
        #expect(notificationSlots.isEmpty)
    }

    @Test("현재 저장소는 재실행해도 그대로 열린다")
    func reopensCurrentStoreWithoutMigration() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "default.store")
        let recordID = UUID()

        try makeCurrentStore(at: storeURL, recordID: recordID)
        let reopenedContainer = try makeCurrentContainer(at: storeURL)
        let records = try reopenedContainer.mainContext.fetch(FetchDescriptor<WhisperRecord>())

        #expect(records.map(\.id) == [recordID])
    }

    private func makeLegacyStore(
        at storeURL: URL,
        recordID: UUID,
        commitmentID: UUID,
        createdAt: Date,
        updatedAt: Date,
        reminderAt: Date,
        photoData: Data
    ) throws {
        let configuration = ModelConfiguration(
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: WhisperLegacyEmberSchema.EmberRecord.self,
            WhisperLegacyEmberSchema.EmberCommitment.self,
            configurations: configuration
        )
        let context = container.mainContext

        context.insert(
            WhisperLegacyEmberSchema.EmberRecord(
                id: recordID,
                title: "1.0 기록",
                content: "업데이트 뒤에도 남아야 하는 내용",
                createdAt: createdAt,
                updatedAt: updatedAt,
                focusMode: "집중",
                emotion: "평온",
                photoData: photoData
            )
        )
        context.insert(
            WhisperLegacyEmberSchema.EmberCommitment(
                id: commitmentID,
                sourceRecordID: recordID,
                name: "매일 걷기",
                quote: "내일부터 매일 걷자",
                topics: ["건강", "산책"],
                createdAt: createdAt,
                nextReminderAt: reminderAt,
                continuationCount: 2
            )
        )
        try context.save()
    }

    private func makeV1Store(
        at storeURL: URL,
        recordID: UUID,
        commitmentID: UUID,
        createdAt: Date
    ) throws {
        let schema = Schema(versionedSchema: WhisperSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        context.insert(
            WhisperSchemaV1.WhisperRecord(
                id: recordID,
                title: "V1 기록",
                content: "V1에서 최신 버전까지 보존",
                createdAt: createdAt
            )
        )
        context.insert(
            WhisperSchemaV1.WhisperCommitment(
                id: commitmentID,
                sourceRecordID: recordID,
                name: "V1 결심",
                quote: "계속 기억하기",
                topics: ["회귀 테스트"],
                createdAt: createdAt
            )
        )
        try context.save()
    }

    private func makeV2Store(
        at storeURL: URL,
        recordID: UUID,
        commitmentID: UUID,
        encounterID: UUID,
        createdAt: Date,
        scheduledAt: Date
    ) throws {
        let schema = Schema(versionedSchema: WhisperSchemaV2.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        context.insert(
            WhisperSchemaV2.WhisperRecord(
                id: recordID,
                title: "V2 기록",
                content: "V3에서도 보존할 내용",
                createdAt: createdAt,
                focusMode: "집중",
                emotion: "평온"
            )
        )
        context.insert(
            WhisperSchemaV2.WhisperCommitment(
                id: commitmentID,
                sourceRecordID: recordID,
                name: "V2 결심",
                quote: "기존 결심을 계속 기억하자",
                topics: ["마이그레이션"],
                createdAt: createdAt,
                nextReminderAt: scheduledAt,
                continuationCount: 2,
                lastEncounteredAt: createdAt,
                lastReadAt: createdAt,
                encounterCount: 3
            )
        )
        context.insert(
            WhisperSchemaV2.ReminderEncounter(
                id: encounterID,
                commitmentID: commitmentID,
                scheduledAt: scheduledAt,
                notificationIdentifier: "whisper.commitment.v2",
                createdAt: createdAt
            )
        )
        try context.save()
    }

    private func makeCurrentStore(at storeURL: URL, recordID: UUID) throws {
        let container = try makeCurrentContainer(at: storeURL)
        container.mainContext.insert(
            WhisperRecord(
                id: recordID,
                title: "현재 기록",
                content: "재실행 뒤에도 보존"
            )
        )
        try container.mainContext.save()
    }

    private func makeCurrentContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: WhisperSchemaV4.self)
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: WhisperMigrationPlan.self,
            configurations: configuration
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "WhisperMigrationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func schemaFingerprint(_ schema: Schema) -> [String] {
        schema.entities
            .flatMap { entity in
                entity.properties.map { property in
                    [
                        "\(entity.name).\(property.name)",
                        String(reflecting: property.valueType),
                        "optional=\(property.isOptional)",
                        "unique=\(property.isUnique)"
                    ].joined(separator: ":")
                }
            }
            .sorted()
    }
}
