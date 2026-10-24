import Foundation

enum WhisperLocalization {
    /// Match the app's selected language while retaining the user's region preferences.
    /// Storage calendars and civil-day keys must never depend on this display locale.
    nonisolated static var locale: Locale {
        displayLocale(language: Bundle.main.preferredLocalizations.first ?? "ko", preferences: .current)
    }

    nonisolated static func displayLocale(language: String, preferences: Locale) -> Locale {
        var components = Locale.Components(identifier: preferences.identifier)
        var languageComponents = Locale.Language.Components(identifier: language)
        languageComponents.region = preferences.region
        components.languageComponents = languageComponents
        // Rebuilding from the identifier alone can lose explicit user overrides.
        components.hourCycle = preferences.hourCycle
        components.firstDayOfWeek = preferences.firstDayOfWeek
        components.numberingSystem = preferences.numberingSystem
        return Locale(components: components)
    }

    nonisolated static func calendar(locale: Locale = locale, timeZone: TimeZone = .current) -> Calendar {
        var calendar = JournalDayKey.calendar(timeZone: timeZone)
        calendar.locale = locale
        return calendar
    }

    /// Keep the weekday labels aligned with the region's calendar columns.
    nonisolated static func weekdaySymbols(locale: Locale = locale) -> [String] {
        let calendar = calendar(locale: locale)
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }
}
