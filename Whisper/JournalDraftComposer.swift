import Foundation

struct JournalDraft {
    let title: String
    let body: String
    let sourceRecordIDs: [UUID]
    let representativeEmotion: String?
}

enum JournalDraftComposer {
    static func compose(
        on date: Date,
        records: [WhisperRecord],
        existing: DailyJournal?,
        calendar: Calendar = .current
    ) -> JournalDraft {
        compose(on: JournalDay(date: date, calendar: calendar), records: records, existing: existing)
    }

    static func compose(on day: JournalDay, records: [WhisperRecord], existing: DailyJournal?) -> JournalDraft {
        let moments = records
            .filter { day.contains($0.createdAt) }
            .sorted { $0.createdAt < $1.createdAt }
        let existingIDs = existing?.sourceRecordIDs ?? []
        let knownIDs = Set(existingIDs)
        let newlyAdded = moments.filter { !knownIDs.contains($0.id) }
        let newText = newlyAdded.map(\.content).joined(separator: "\n\n")
        let body = [existing?.body ?? "", newText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        return JournalDraft(
            title: existing?.title ?? "",
            body: body,
            sourceRecordIDs: existingIDs + newlyAdded.map(\.id),
            representativeEmotion: existing == nil ? representativeEmotion(in: moments) : existing?.emotion
        )
    }

    static func representativeEmotion(in records: [WhisperRecord]) -> String? {
        let emotions = records.compactMap(\.emotion)
        guard !emotions.isEmpty else { return nil }
        let counts = Dictionary(emotions.map { ($0, 1) }, uniquingKeysWith: +)
        let highest = counts.values.max() ?? 0
        return emotions.reversed().first { counts[$0] == highest }
    }
}
