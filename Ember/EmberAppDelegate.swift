//
//  EmberAppDelegate.swift
//  Ember
//

import UIKit
import UserNotifications

enum EmberNotificationRoute {
    static let didSelectRecord = Notification.Name("EmberDidSelectNotificationRecord")
    private static let pendingRecordIDKey = "ember.notification.pendingRecordID"
    private static let pendingCommitmentIDKey = "ember.notification.pendingCommitmentID"

    @MainActor
    static func store(_ recordID: UUID, commitmentID: UUID?) {
        UserDefaults.standard.set(recordID.uuidString, forKey: pendingRecordIDKey)
        if let commitmentID {
            UserDefaults.standard.set(commitmentID.uuidString, forKey: pendingCommitmentIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pendingCommitmentIDKey)
        }
        NotificationCenter.default.post(name: didSelectRecord, object: nil)
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
}

final class EmberAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
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
        EmberNotificationRoute.store(recordID, commitmentID: commitmentID)
    }
}
