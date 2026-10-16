import Foundation

/// The civil day and time zone captured when a journal is opened or collected.
struct JournalDay: Codable, Equatable {
    let key: String
    let calendar: Calendar
    let date: Date

    init(date: Date, calendar: Calendar = .current) {
        let gregorian = JournalDayKey.calendar(timeZone: calendar.timeZone)
        self.calendar = gregorian
        self.date = gregorian.startOfDay(for: date)
        key = JournalDayKey.make(for: date, calendar: gregorian)
    }

    func contains(_ date: Date) -> Bool {
        JournalDayKey.make(for: date, calendar: calendar) == key
    }

    var nextBoundary: Date {
        calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
    }

    var fullDescription: String {
        fullDescription(locale: WhisperLocalization.locale)
    }

    func fullDescription(locale: Locale) -> String {
        date.formatted(Date.FormatStyle(
            locale: locale, calendar: calendar, timeZone: calendar.timeZone
        ).year().month(.wide).day().weekday(.wide))
    }

    var shortDescription: String {
        date.formatted(Date.FormatStyle(
            locale: WhisperLocalization.locale, calendar: calendar, timeZone: calendar.timeZone
        ).month(.wide).day())
    }

    var reflectionTimeDescription: String {
        let time = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: date) ?? date
        return time.formatted(Date.FormatStyle(
            locale: WhisperLocalization.locale, calendar: calendar, timeZone: calendar.timeZone
        ).hour().minute())
    }
}

enum JournalDayKey {
    static func calendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func make(for date: Date, calendar: Calendar = .current) -> String {
        rawKey(for: date, calendar: self.calendar(timeZone: calendar.timeZone))
    }

    private static func rawKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func date(for key: String, timeZone: TimeZone = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let gregorian = calendar(timeZone: timeZone)
        guard let date = gregorian.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              rawKey(for: date, calendar: gregorian) == key else { return nil }
        return date
    }

    /// Old releases used the system calendar and saved its local midnight as `date`.
    /// Recover the civil date without rewriting unique keys or merging journal contents.
    static func persistedKey(_ key: String, date storedDate: Date) -> String? {
        let utc = TimeZone(secondsFromGMT: 0)!
        if let civilDate = date(for: key, timeZone: utc), abs(civilDate.timeIntervalSince(storedDate)) <= 14 * 3_600 {
            return key
        }

        let utcCalendar = calendar(timeZone: utc)
        let seconds = Int(storedDate.timeIntervalSince(utcCalendar.startOfDay(for: storedDate)).rounded())
        let offsets = [-seconds, 86_400 - seconds].filter { (-12 * 3_600 ... 14 * 3_600).contains($0) }
        let identifiers: [Calendar.Identifier] = [
            .gregorian, .buddhist, .japanese, .republicOfChina, .chinese, .hebrew,
            .islamic, .islamicCivil, .islamicTabular, .islamicUmmAlQura, .persian,
            .indian, .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem, .iso8601
        ]
        var recovered = Set<String>()
        for offset in offsets {
            guard let timeZone = TimeZone(secondsFromGMT: offset) else { continue }
            for identifier in identifiers {
                var originalCalendar = Calendar(identifier: identifier)
                originalCalendar.timeZone = timeZone
                if rawKey(for: storedDate, calendar: originalCalendar) == key {
                    recovered.insert(make(for: storedDate, calendar: originalCalendar))
                }
            }
        }
        return recovered.count == 1 ? recovered.first : nil
    }
}

extension DailyJournal {
    var civilDayKey: String? {
        JournalDayKey.persistedKey(dayKey, date: date)
    }

    var displayDate: Date {
        civilDayKey.flatMap { JournalDayKey.date(for: $0) } ?? date
    }
}
