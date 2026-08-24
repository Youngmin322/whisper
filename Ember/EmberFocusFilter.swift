//
//  EmberFocusFilter.swift
//  Ember
//

import AppIntents
import UserNotifications

enum EmberFocusMode: String, AppEnum {
    case work = "업무 집중 모드"
    case exercise = "운동"
    case reading = "독서"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Ember FocusMode"

    static var caseDisplayRepresentations: [EmberFocusMode: DisplayRepresentation] = [
        .work: "업무 집중 모드",
        .exercise: "운동",
        .reading: "독서"
    ]
}

struct EmberFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "연결한 기록 다시 만나기"
    static var description = IntentDescription(
        "집중 모드가 시작되면 선택한 Ember FocusMode에 연결된 기록을 알림으로 다시 보여줘요."
    )

    @Parameter(title: "Ember FocusMode")
    var mode: EmberFocusMode?

    init() {}

    init(mode: EmberFocusMode) {
        self.mode = mode
    }

    var displayRepresentation: DisplayRepresentation {
        switch mode {
        case .work:
            DisplayRepresentation(title: "Ember", subtitle: "업무 집중 모드 기록")
        case .exercise:
            DisplayRepresentation(title: "Ember", subtitle: "운동 기록")
        case .reading:
            DisplayRepresentation(title: "Ember", subtitle: "독서 기록")
        case nil:
            DisplayRepresentation(title: "Ember", subtitle: "연결한 기록 다시 만나기")
        }
    }

    static func suggestedFocusFilters(
        for context: FocusFilterSuggestionContext
    ) async -> [EmberFocusFilter] {
        EmberFocusMode.allCases.map(EmberFocusFilter.init(mode:))
    }

    func perform() async throws -> some IntentResult {
        guard let mode else { return .result() }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional
        else {
            return .result()
        }

        let reminder: (id: UUID, content: String)? = await MainActor.run {
            let recordStore = RecordStore()
            let records = recordStore.records(linkedTo: mode.rawValue)
            guard !records.isEmpty else { return nil }

            let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
            let record = records[day % records.count]
            return (record.id, record.content)
        }
        guard let reminder else { return .result() }

        let content = UNMutableNotificationContent()
        content.title = "다시 만난 불꽃"
        content.subtitle = mode.rawValue
        content.body = String(reminder.content.prefix(180))
        content.sound = .default
        content.threadIdentifier = "ember.focus.\(mode.rawValue)"
        content.userInfo = ["recordID": reminder.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "ember.focus.\(mode.rawValue).\(reminder.id.uuidString)",
            content: content,
            trigger: nil
        )
        try await UNUserNotificationCenter.current().add(request)
        return .result()
    }

}
