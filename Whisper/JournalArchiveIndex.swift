import Foundation

struct JournalArchiveDay: Identifiable {
    let day: JournalDay
    let journals: [DailyJournal]
    let uncollectedMoments: [WhisperRecord]

    var id: String { day.key }
    var hasJournal: Bool { !journals.isEmpty }
    var hasUncollectedMoments: Bool { !uncollectedMoments.isEmpty }
    var canCollect: Bool { hasUncollectedMoments && journals.count <= 1 }

    var collectionTitle: String {
        hasJournal ? "새 순간 \(uncollectedMoments.count)개 함께 담기" : "이날의 순간 병에 담기"
    }

    var accessibilityDescription: String {
        let journalText = hasJournal ? "담긴 하루 \(journals.count)개" : ""
        let momentText = hasUncollectedMoments ? "아직 담지 않은 순간 \(uncollectedMoments.count)개" : ""
        return [day.fullDescription, journalText, momentText].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct JournalArchiveSearchResult: Identifiable {
    enum Kind: String {
        case journal, moment

        var label: String { self == .journal ? "일기" : "미보관 순간" }
    }

    let kind: Kind
    let recordID: UUID
    let day: JournalDay
    let createdAt: Date
    let title: String
    let preview: String
    let emotion: String?
    fileprivate let searchableTexts: [String]

    var id: String { "\(kind.rawValue):\(recordID.uuidString)" }
}

/// Calendar and search share the same definition of an uncollected moment.
struct JournalArchiveIndex {
    let days: [JournalArchiveDay]
    private let daysByKey: [String: JournalArchiveDay]
    private let searchResults: [JournalArchiveSearchResult]

    init(records: [WhisperRecord], journals: [DailyJournal], calendar: Calendar = .current) {
        let calendar = JournalDayKey.calendar(timeZone: calendar.timeZone)
        let collectedIDs = Set(journals.flatMap(\.sourceRecordIDs))
        let moments = records.filter { !collectedIDs.contains($0.id) }
        let momentsByDay = Dictionary(grouping: moments) { JournalDayKey.make(for: $0.createdAt, calendar: calendar) }
        let journalsByDay = Dictionary(grouping: journals) {
            $0.civilDayKey ?? JournalDayKey.make(for: $0.date, calendar: calendar)
        }
        let keys = Set(momentsByDay.keys).union(journalsByDay.keys)
        let entries = keys.compactMap { key -> JournalArchiveDay? in
            guard let date = JournalDayKey.date(for: key, timeZone: calendar.timeZone) else { return nil }
            return JournalArchiveDay(
                day: JournalDay(date: date, calendar: calendar),
                journals: (journalsByDay[key] ?? []).sorted { $0.id.uuidString < $1.id.uuidString },
                uncollectedMoments: (momentsByDay[key] ?? []).sorted { $0.createdAt < $1.createdAt }
            )
        }
        days = entries.sorted { $0.day.key > $1.day.key }
        daysByKey = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })

        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        var results: [JournalArchiveSearchResult] = []
        for entry in entries {
            for journal in entry.journals {
                var texts = [journal.title, journal.body, journal.reflection, journal.emotion ?? ""]
                for id in journal.sourceRecordIDs {
                    guard let source = recordsByID[id] else { continue }
                    texts += [source.title, source.content, source.emotion ?? ""]
                }
                let title = journal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                results.append(JournalArchiveSearchResult(
                    kind: .journal, recordID: journal.id, day: entry.day, createdAt: journal.date,
                    title: title.isEmpty ? "이날의 하루" : title, preview: journal.body,
                    emotion: journal.emotion, searchableTexts: texts
                ))
            }
            for moment in entry.uncollectedMoments {
                let title = moment.title.trimmingCharacters(in: .whitespacesAndNewlines)
                results.append(JournalArchiveSearchResult(
                    kind: .moment, recordID: moment.id, day: entry.day, createdAt: moment.createdAt,
                    title: title.isEmpty ? "남겨둔 순간" : title, preview: moment.content,
                    emotion: moment.emotion,
                    searchableTexts: [moment.title, moment.content, moment.emotion ?? ""]
                ))
            }
        }
        searchResults = results.sorted {
            if $0.day.key != $1.day.key { return $0.day.key > $1.day.key }
            if $0.kind != $1.kind { return $0.kind == .journal }
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id < $1.id
        }
    }

    func entry(for key: String) -> JournalArchiveDay? { daysByKey[key] }

    func results(matching query: String) -> [JournalArchiveSearchResult] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return searchResults }
        return searchResults.filter { result in
            result.searchableTexts.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}
