//
//  WhisperFocusFilter.swift
//  Whisper
//

import AppIntents
import UserNotifications

struct WhisperRecordEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "불꽃"
    static var defaultQuery = WhisperRecordEntityQuery()

    let id: String
    let title: String
    let contentPreview: String

    init(record: WhisperRecord) {
        id = record.id.uuidString
        title = record.title
        contentPreview = String(record.content.prefix(60))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(contentPreview)"
        )
    }
}

struct WhisperRecordEntityQuery: EntityQuery {
    func entities(for identifiers: [WhisperRecordEntity.ID]) async throws
        -> [WhisperRecordEntity]
    {
        await MainActor.run {
            let identifierSet = Set(identifiers)
            return RecordStore().records
                .filter { identifierSet.contains($0.id.uuidString) }
                .map(WhisperRecordEntity.init(record:))
        }
    }

    func suggestedEntities() async throws -> [WhisperRecordEntity] {
        await MainActor.run {
            RecordStore().records.map(WhisperRecordEntity.init(record:))
        }
    }
}

struct WhisperFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "다시 만날 불꽃 선택"
    static var description = IntentDescription(
        "이 집중 모드가 시작될 때 다시 만날 Whisper 불꽃을 선택해요."
    )
    static var supportedModes: IntentModes = .background

    @Parameter(title: "다시 만날 불꽃")
    var flames: [WhisperRecordEntity]?

    init() {}

    var displayRepresentation: DisplayRepresentation {
        guard let flames, !flames.isEmpty else {
            return DisplayRepresentation(
                title: "Whisper",
                subtitle: "다시 만날 불꽃 선택"
            )
        }

        return DisplayRepresentation(
            title: "Whisper",
            subtitle: "\(flames.count)개의 불꽃"
        )
    }

    func perform() async throws -> some IntentResult {
        guard let flames, !flames.isEmpty else { return .result() }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional
        else {
            return .result()
        }

        let reminder: (id: UUID, title: String, content: String)? = await MainActor.run {
            let recordStore = RecordStore()
            let selectedIDs = Set(flames.compactMap { UUID(uuidString: $0.id) })
            let records = recordStore.records.filter { selectedIDs.contains($0.id) }
            guard !records.isEmpty else { return nil }

            let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
            let record = records[day % records.count]
            return (record.id, record.title, record.content)
        }
        guard let reminder else { return .result() }

        let content = UNMutableNotificationContent()
        content.title = "다시 만난 불꽃"
        content.subtitle = reminder.title
        content.body = String(reminder.content.prefix(180))
        content.sound = .default
        content.threadIdentifier = "whisper.focus.records"
        content.userInfo = ["recordID": reminder.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "whisper.focus.\(reminder.id.uuidString)",
            content: content,
            trigger: nil
        )
        try await UNUserNotificationCenter.current().add(request)
        return .result()
    }
}
