import Foundation
import Observation
import Testing
@testable import Whisper

@Suite("앱 내부 언어 선택")
struct WhisperLanguageSettingsTests {
    @Test("선택한 언어는 저장되고 새 설정 인스턴스에서도 복원된다")
    func persistsOnlyAppLanguage() throws {
        let suite = "WhisperLanguageSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["ja", "en"], forKey: "AppleLanguages")
        defaults.set(Data([1, 2, 3]), forKey: "existing-content")
        let settings = WhisperLanguageSettings(defaults: defaults)
        #expect(settings.selection == .system)
        for language in WhisperAppLanguage.allCases {
            settings.selection = language
            #expect(WhisperLanguageSettings(defaults: defaults).selection == language)
        }
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["ja", "en"])
        #expect(defaults.data(forKey: "existing-content") == Data([1, 2, 3]))
        defaults.set("unsupported-language", forKey: WhisperLanguageSettings.storageKey)
        #expect(settings.selection == .system)
    }

    @Test("시스템 언어와 수동 선택을 구분하고 지원하지 않는 언어는 한국어로 표시한다")
    func resolvesLanguageAndBundle() throws {
        #expect(WhisperLocalization.languageCode(for: .system, systemLocalizations: ["en-GB", "ko"]) == "en")
        #expect(WhisperLocalization.languageCode(for: .system, systemLocalizations: ["ko-KR", "en"]) == "ko")
        #expect(WhisperLocalization.languageCode(for: .system, systemLocalizations: ["ja"]) == "ko")
        #expect(WhisperLocalization.languageCode(for: .korean, systemLocalizations: ["en"]) == "ko")
        #expect(WhisperLocalization.languageCode(for: .english, systemLocalizations: ["ko"]) == "en")
        for (language, expected) in [("ko", "보관함"), ("en", "Archive"), ("ja", "보관함")] {
            let bundle = WhisperLocalization.bundle(for: language)
            #expect(String(localized: "보관함", bundle: bundle) == expected)
        }
    }

    @Test("번역을 읽는 화면은 언어 선택 변경을 관찰할 수 있다")
    func notifiesReaders() async throws {
        let suite = "WhisperLanguageObservationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = WhisperLanguageSettings(defaults: defaults)
        await confirmation("Language selection invalidates its readers") { changed in
            withObservationTracking {
                _ = WhisperLocalization.languageCode(for: settings.selection)
            } onChange: {
                changed()
            }
            settings.selection = .english
        }
        #expect(settings.selection == .english)
    }
}
