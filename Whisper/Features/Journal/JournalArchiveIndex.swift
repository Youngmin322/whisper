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
        hasJournal ? String(localized: "새 순간 \(uncollectedMoments.count)개 함께 담기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : String(localized: "이날의 순간 병에 담기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
    }

    var accessibilityDescription: String {
        let journalText = hasJournal ? String(localized: "담긴 하루 \(journals.count)개", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : ""
        let momentText = hasUncollectedMoments ? String(localized: "아직 담지 않은 순간 \(uncollectedMoments.count)개", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : ""
        return [day.fullDescription, journalText, momentText].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct JournalArchiveSearchResult: Identifiable {
    enum Kind: String {
        case journal, moment

        var label: String { self == .journal ? String(localized: "일기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : String(localized: "미보관 순간", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) }
    }

    let kind: Kind
    let recordID: UUID
    let day: JournalDay
    let createdAt: Date
    let title: String
    var preview: String
    let emotion: String?
    fileprivate let searchableTexts: [JournalSearchText]
    var searchContext: JournalSearchContext? = nil

    var id: String { "\(kind.rawValue):\(recordID.uuidString)" }
}

struct JournalSearchText: Equatable {
    enum Field: Equatable { case body, reflection, title, emotion }
    let field: Field
    /// A nil ID refers to the result itself; an ID refers to a collected source moment.
    let sourceID: UUID?
    let text: String

    static func emotionNames(_ value: String?, sourceID: UUID?) -> [Self] {
        WhisperEmotion.searchNames(for: value).map { Self(field: .emotion, sourceID: sourceID, text: $0) }
    }
}

struct JournalSearchMatch: Equatable {
    let field: JournalSearchText.Field
    let sourceID: UUID?
    let snippet: String
}

struct JournalSearchContext: Equatable {
    let query: String
    let matches: [JournalSearchMatch]

    var opensSources: Bool { matches.first?.sourceID != nil }
    var sourceIDs: Set<UUID> { Set(matches.compactMap(\.sourceID)) }

    func description(for kind: JournalArchiveSearchResult.Kind) -> String? {
        guard let first = matches.first else { return nil }
        if first.sourceID != nil {
            return sourceIDs.count > 1 ? String(localized: "담아 둔 순간 \(sourceIDs.count)개에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : String(localized: "담아 둔 순간에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        }
        switch (kind, first.field) {
        case (.journal, .body): return String(localized: "일기 본문에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case (.moment, .body): return String(localized: "순간 본문에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case (_, .reflection): return String(localized: "일기 회고에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case (.journal, .title): return String(localized: "일기 제목에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case (.moment, .title): return String(localized: "순간 제목에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case (.journal, .emotion): return String(localized: "일기 감정에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case (.moment, .emotion): return String(localized: "순간 감정에서 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        }
    }
}

enum JournalSearchSnippet {
    static func range(of query: String, in text: String, within range: Range<String.Index>? = nil) -> Range<String.Index>? {
        guard !query.isEmpty else { return nil }
        return text.range(of: query, options: .caseInsensitive, range: range, locale: .current)
    }

    static func make(in text: String, query: String) -> String? {
        guard let match = range(of: query, in: text) else { return nil }
        let start = text.index(match.lowerBound, offsetBy: -24, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(match.upperBound, offsetBy: 72, limitedBy: text.endIndex) ?? text.endIndex
        let excerpt = text[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return (start > text.startIndex ? "…" : "") + excerpt + (end < text.endIndex ? "…" : "")
    }
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
                // Prefer the finished diary whenever it also contains the search term.
                var texts = [
                    JournalSearchText(field: .body, sourceID: nil, text: journal.body),
                    JournalSearchText(field: .reflection, sourceID: nil, text: journal.reflection),
                    JournalSearchText(field: .title, sourceID: nil, text: journal.title)
                ] + JournalSearchText.emotionNames(journal.emotion, sourceID: nil)
                for id in journal.sourceRecordIDs {
                    guard let source = recordsByID[id] else { continue }
                    texts += [
                        JournalSearchText(field: .body, sourceID: id, text: source.content),
                        JournalSearchText(field: .title, sourceID: id, text: source.title)
                    ] + JournalSearchText.emotionNames(source.emotion, sourceID: id)
                }
                let title = journal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                results.append(JournalArchiveSearchResult(
                    kind: .journal, recordID: journal.id, day: entry.day, createdAt: journal.date,
                    title: title.isEmpty ? String(localized: "이날의 하루", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : title, preview: journal.body,
                    emotion: journal.emotion, searchableTexts: texts
                ))
            }
            for moment in entry.uncollectedMoments {
                let title = moment.title.trimmingCharacters(in: .whitespacesAndNewlines)
                results.append(JournalArchiveSearchResult(
                    kind: .moment, recordID: moment.id, day: entry.day, createdAt: moment.createdAt,
                    title: title.isEmpty ? String(localized: "남겨둔 순간", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : title, preview: moment.content,
                    emotion: moment.emotion,
                    searchableTexts: [
                        JournalSearchText(field: .body, sourceID: nil, text: moment.content),
                        JournalSearchText(field: .title, sourceID: nil, text: moment.title)
                    ] + JournalSearchText.emotionNames(moment.emotion, sourceID: nil)
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
        return searchResults.compactMap { result in
            let matches = result.searchableTexts.compactMap { item -> JournalSearchMatch? in
                guard let snippet = JournalSearchSnippet.make(in: item.text, query: query) else { return nil }
                return JournalSearchMatch(field: item.field, sourceID: item.sourceID, snippet: snippet)
            }
            guard let first = matches.first else { return nil }
            var found = result
            found.preview = first.snippet
            found.searchContext = JournalSearchContext(query: query, matches: matches)
            return found
        }
    }
}
