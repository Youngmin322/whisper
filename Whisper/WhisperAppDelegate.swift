//
//  WhisperAppDelegate.swift
//  Whisper
//

import UIKit
import UserNotifications
import WhisperDesignSystem

enum WhisperNotificationRoute {
    static let didSelectRecord = Notification.Name("WhisperDidSelectNotificationRecord")
    static let didPresentEncounter = Notification.Name("WhisperDidPresentReminderEncounter")
    private static let pendingRecordIDKey = "whisper.notification.pendingRecordID"
    private static let pendingCommitmentIDKey = "whisper.notification.pendingCommitmentID"
    private static let pendingEncounterIDKey = "whisper.notification.pendingEncounterID"
    private static let pendingRequestIdentifierKey = "whisper.notification.pendingRequestIdentifier"

    @MainActor
    static func store(
        _ recordID: UUID,
        commitmentID: UUID?,
        encounterID: UUID?,
        requestIdentifier: String?
    ) {
        UserDefaults.standard.set(recordID.uuidString, forKey: pendingRecordIDKey)
        if let commitmentID {
            UserDefaults.standard.set(commitmentID.uuidString, forKey: pendingCommitmentIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pendingCommitmentIDKey)
        }
        if let encounterID {
            UserDefaults.standard.set(encounterID.uuidString, forKey: pendingEncounterIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pendingEncounterIDKey)
        }
        if let requestIdentifier {
            UserDefaults.standard.set(requestIdentifier, forKey: pendingRequestIdentifierKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pendingRequestIdentifierKey)
        }
        NotificationCenter.default.post(name: didSelectRecord, object: nil)
    }

    @MainActor
    static func postPresented(_ encounterID: UUID) {
        NotificationCenter.default.post(name: didPresentEncounter, object: encounterID)
    }

    @MainActor
    static func consumePendingRecordID() -> UUID? {
        guard let value = UserDefaults.standard.string(forKey: pendingRecordIDKey),
              let recordID = UUID(uuidString: value)
        else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: pendingRecordIDKey)
        return recordID
    }

    @MainActor
    static func consumePendingCommitmentID() -> UUID? {
        guard let value = UserDefaults.standard.string(forKey: pendingCommitmentIDKey),
              let commitmentID = UUID(uuidString: value)
        else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: pendingCommitmentIDKey)
        return commitmentID
    }

    @MainActor
    static func consumePendingEncounterID() -> UUID? {
        guard let value = UserDefaults.standard.string(forKey: pendingEncounterIDKey),
              let encounterID = UUID(uuidString: value)
        else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: pendingEncounterIDKey)
        return encounterID
    }

    @MainActor
    static func consumePendingRequestIdentifier() -> String? {
        guard let identifier = UserDefaults.standard.string(
            forKey: pendingRequestIdentifierKey
        ) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: pendingRequestIdentifierKey)
        return identifier
    }
}

final class WhisperAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        WhisperFont.register()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let encounterID = (notification.request.content.userInfo["encounterID"] as? String)
            .flatMap(UUID.init(uuidString:))
        if let encounterID {
            await MainActor.run {
                WhisperNotificationRoute.postPresented(encounterID)
            }
        }
        return [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let value = response.notification.request.content.userInfo["recordID"] as? String,
              let recordID = UUID(uuidString: value)
        else {
            return
        }

        let commitmentID = (response.notification.request.content.userInfo["commitmentID"] as? String)
            .flatMap(UUID.init(uuidString:))
        let encounterID = (response.notification.request.content.userInfo["encounterID"] as? String)
            .flatMap(UUID.init(uuidString:))
        await MainActor.run {
            WhisperNotificationRoute.store(
                recordID,
                commitmentID: commitmentID,
                encounterID: encounterID,
                requestIdentifier: response.notification.request.identifier
            )
        }
    }
}
