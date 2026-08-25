//
//  EmberAppDelegate.swift
//  Ember
//

import UIKit
import UserNotifications

enum EmberNotificationRoute {
    static let didSelectRecord = Notification.Name("EmberDidSelectNotificationRecord")
    private static let pendingRecordIDKey = "ember.notification.pendingRecordID"

    @MainActor
    static func store(_ recordID: UUID) {
        UserDefaults.standard.set(recordID.uuidString, forKey: pendingRecordIDKey)
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

        EmberNotificationRoute.store(recordID)
    }
}
