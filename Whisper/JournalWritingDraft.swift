import Foundation

struct JournalWritingDraft: Codable, Equatable, Identifiable {
    var id = UUID()
    let day: JournalDay
    let existingJournalID: UUID?
    var title: String
    var body: String
    var sourceRecordIDs: [UUID]
    var representativeEmotion: String?

    var storageKey: String {
        existingJournalID.map { "journal:edit:\($0.uuidString)" } ?? "journal:new:\(day.key)"
    }

    init(day: JournalDay, existing: DailyJournal?, records: [WhisperRecord]) {
        self.day = day
        existingJournalID = existing?.id
        let composed = JournalDraftComposer.compose(on: day, records: records, existing: existing)
        title = composed.title
        body = composed.body
        sourceRecordIDs = composed.sourceRecordIDs
        representativeEmotion = composed.representativeEmotion
    }

    func includingNewMoments(from records: [WhisperRecord]) -> Self {
        var resumed = self
        let known = Set(sourceRecordIDs)
        let added = records.filter { day.contains($0.createdAt) && !known.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        guard !added.isEmpty else { return resumed }
        resumed.body = [body, added.map(\.content).joined(separator: "\n\n")]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
        resumed.sourceRecordIDs += added.map(\.id)
        return resumed
    }
}
