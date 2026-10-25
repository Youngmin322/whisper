import Foundation
import Observation

nonisolated enum WhisperAppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            String(localized: "시스템 설정 따르기", bundle: WhisperLocalization.bundle,
                   locale: WhisperLocalization.locale)
        case .korean: "한국어"
        case .english: "English"
        }
    }
}

/// Only the thread-safe defaults store and Observation registrar hold state.
/// Notification copy can also read the preference outside the main actor.
@Observable
nonisolated final class WhisperLanguageSettings: @unchecked Sendable {
    static let shared = WhisperLanguageSettings()
    static let storageKey = "whisper.appLanguage"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selection: WhisperAppLanguage {
        get {
            access(keyPath: \.selection)
            return WhisperAppLanguage(rawValue: defaults.string(forKey: Self.storageKey) ?? "") ?? .system
        }
        set {
            guard newValue != selection else { return }
            withMutation(keyPath: \.selection) {
                defaults.set(newValue.rawValue, forKey: Self.storageKey)
            }
        }
    }
}
