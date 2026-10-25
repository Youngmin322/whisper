import Foundation

enum WhisperLocalization {
    nonisolated static var languageCode: String {
        languageCode(for: WhisperLanguageSettings.shared.selection)
    }

    nonisolated static func languageCode(
        for selection: WhisperAppLanguage,
        systemLocalizations: [String] = Bundle.main.preferredLocalizations
    ) -> String {
        switch selection {
        case .korean: "ko"
        case .english: "en"
        case .system:
            systemLocalizations.lazy.compactMap { Locale(identifier: $0).language.languageCode?.identifier }
                .first { $0 == "ko" || $0 == "en" } ?? "ko"
        }
    }

    nonisolated static var bundle: Bundle {
        resourceBundles[languageCode] ?? .main
    }

    nonisolated private static let resourceBundles = ["ko": bundle(for: "ko"), "en": bundle(for: "en")]

    nonisolated static func bundle(for language: String, in resources: Bundle = .main) -> Bundle {
        let supportedLanguage = language == "en" ? "en" : "ko"
        guard let path = resources.path(forResource: supportedLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return resources }
        return bundle
    }

    /// Match the app's selected language while retaining the user's region preferences.
    /// Storage calendars and civil-day keys must never depend on this display locale.
    nonisolated static var locale: Locale {
        displayLocale(language: languageCode, preferences: .current)
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
