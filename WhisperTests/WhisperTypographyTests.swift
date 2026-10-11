import CoreText
import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("일기 글꼴")
struct WhisperTypographyTests {
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
}
