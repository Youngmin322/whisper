import CoreText
import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("일기 글꼴")
struct WhisperTypographyTests {
    @Test("온보딩 글꼴과 이전 이미지 API의 리소스를 앱 번들에서 찾을 수 있다")
    func appBundleContainsMovedResources() throws {
        for name in ["Pretendard-Regular", "Pretendard-Medium", "Pretendard-SemiBold", "Pretendard-Bold"] {
            _ = try #require(Bundle.main.url(forResource: name, withExtension: "otf"))
            let font = try #require(UIFont(name: name, size: 18))
            #expect(font.fontName == name)
        }
        for name in ["Whisper", "WhisperJar", "WhisperFlame", "WhisperCorkscrew", "Jar",
                     "QuickRecordIllustration", "DetailRecordIllustration"] {
            let image = try #require(UIImage(named: name))
            #expect(image.size.width > 0 && image.size.height > 0)
        }
    }

    @Test("앱에 등록된 교보 손글씨는 한글 11,172자 모두 실제 글자 모양을 갖는다")
    func bundledHandwritingSupportsAllModernHangul() throws {
        let font = try #require(UIFont(name: WhisperTypography.handwritingFontName, size: 18))
        #expect(font.fontName == "KyoboHandwriting2019")
        let coreFont = font as CTFont
        var characters = Array(UInt16(0xAC00)...UInt16(0xD7A3))
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        #expect(CTFontGetGlyphsForCharacters(coreFont, &characters, &glyphs, characters.count))
        let missing = zip(characters, glyphs).filter { _, glyph in
            glyph == 0 || (CTFontCreatePathForGlyph(coreFont, glyph, nil)?.isEmpty ?? true)
        }.map { String(UnicodeScalar($0.0)!) }
        #expect(missing.isEmpty, "빈 글자: \(missing.prefix(10))")
    }

    @Test("화면 글꼴과 손글씨가 영어 알파벳·숫자·문장 부호를 지원한다")
    func bundledFontsSupportEnglish() throws {
        for name in [WhisperTypography.handwritingFontName, "NotoSansKR-Thin"] {
            let font = try #require(UIFont(name: name, size: 18)) as CTFont
            var characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,!?':;()–…“”".utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            #expect(CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count))
            #expect(!glyphs.contains(0))
        }
    }
}
