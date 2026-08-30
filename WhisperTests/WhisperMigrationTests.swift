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

        let currentSchema = Schema(versionedSchema: WhisperSchemaV2.self)
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
        #expect(encounters.isEmpty)
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
}
