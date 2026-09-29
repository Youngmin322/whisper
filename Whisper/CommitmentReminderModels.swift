//
//  CommitmentReminderModels.swift
//  Whisper
//

import Foundation

struct CommitmentSnapshot: Sendable {
    let id: UUID
    let name: String
    let quote: String
    let topics: [String]
    let createdAt: Date
    let lastContinuedAt: Date?
    let continuationCount: Int
}

struct ReminderRecordSnapshot: Sendable {
    let title: String
    let content: String
    let createdAt: Date
}

struct CommitmentReminderPlanningContext: Sendable {
    let commitment: CommitmentSnapshot
    let recentRecords: [ReminderRecordSnapshot]
}

struct CommitmentReminderPlan: Sendable {
    let id: UUID
    let sourceRecordID: UUID
    let name: String
    let quote: String
    let reminderDates: [Date]
}

struct NotificationDaySlotDraft: Sendable {
    let dayKey: String
    let scheduledAt: Date
    let requestIdentifier: String
    let sourceStorage: String
    let commitmentID: UUID?
    let recordID: UUID?
    let consumedAt: Date?
    let createdAt: Date

    init(
        dayKey: String,
        scheduledAt: Date,
        requestIdentifier: String,
        sourceStorage: String,
        commitmentID: UUID? = nil,
        recordID: UUID? = nil,
        consumedAt: Date? = nil,
        createdAt: Date = .now
    ) {
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
