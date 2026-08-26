//
//  CommitmentReminderScheduler.swift
//  Whisper
//

import Foundation
import UserNotifications

enum CommitmentReminderScheduler {
    static let showPreviewStorageKey = "whisper.commitment.showNotificationPreview"

    static func schedule(_ plan: CommitmentReminderPlan) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        guard try await ensureAuthorization(using: center) else { return false }

        await cancel(commitmentIDs: [plan.id])

        let showPreview = UserDefaults.standard.bool(forKey: showPreviewStorageKey)
        let calendar = Calendar.current

        for (index, reminderDate) in plan.reminderDates.enumerated() {
            let dateComponents = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )

            let content = UNMutableNotificationContent()
            content.title = "과거의 불꽃"
            content.body = showPreview
                ? "“\(String(plan.quote.prefix(90)))” 그 마음은 지금도 남아 있나요?"
                : "기억해 둔 마음을 다시 만나볼까요?"
            content.sound = .default
            content.threadIdentifier = "whisper.commitments"
            content.userInfo = [
                "recordID": plan.sourceRecordID.uuidString,
                "commitmentID": plan.id.uuidString
            ]

            let request = UNNotificationRequest(
                identifier: requestIdentifier(commitmentID: plan.id, index: index),
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )
            )
            try await center.add(request)
        }

        return true
    }

    static func cancel(commitmentIDs: [UUID]) async {
        let identifiers = commitmentIDs.flatMap { commitmentID in
            (0..<3).map {
                requestIdentifier(commitmentID: commitmentID, index: $0)
            }
        }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

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

    private static func requestIdentifier(commitmentID: UUID, index: Int) -> String {
        "whisper.commitment.\(commitmentID.uuidString).\(index)"
    }
}
