import CoreText
import Foundation

private let pretendardFontNames = [
    "Pretendard-Thin",
    "Pretendard-ExtraLight",
    "Pretendard-Light",
    "Pretendard-Regular",
    "Pretendard-Medium",
    "Pretendard-SemiBold",
    "Pretendard-Bold",
    "Pretendard-ExtraBold",
    "Pretendard-Black"
]

private let registerPretendardFonts: Void = {
    for name in pretendardFontNames {
        guard let url = Bundle.main.url(forResource: name, withExtension: "otf") else {
            continue
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}()

enum WhisperFont {
    static func register() {
        _ = registerPretendardFonts
    }
}
