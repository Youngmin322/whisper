//
//  WhisperNotificationContentPolicy.swift
//  Whisper
//

import Foundation

struct FocusReminderNotificationCopy: Equatable, Sendable {
    let subtitle: String?
    let body: String

    nonisolated init(subtitle: String?, body: String) {
        self.subtitle = subtitle
        self.body = body
    }
}

enum WhisperNotificationContentPolicy {
    nonisolated static func focusReminderCopy(
        title: String,
        content: String,
        showPreview: Bool
    ) -> FocusReminderNotificationCopy {
        guard showPreview else {
            return FocusReminderNotificationCopy(
                subtitle: nil,
                body: "집중하는 순간에 다시 만나기로 한 마음이 있어요."
            )
        }

        return FocusReminderNotificationCopy(
            subtitle: title,
            body: String(content.prefix(180))
        )
    }
}
