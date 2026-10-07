//
//  Font+Whisper.swift
//  Whisper
//
//  Created by Youngmin Cho on 8/11/26.
//

import SwiftUI

extension Font {
    private static func noto(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("NotoSansKR-Thin", size: size, relativeTo: .body).weight(weight)
    }

    static let whisperBrand = noto(30, weight: .bold)
    static let whisperScreenTitle = noto(26, weight: .bold)
    static let whisperNavigationTitle = noto(18, weight: .medium)
    static let whisperSectionTitle = noto(17, weight: .bold)
    static let whisperFieldLabel = noto(16, weight: .bold)
    static let whisperAction = noto(16, weight: .bold)
    static let whisperBodyLarge = noto(16)
    static let whisperBody = noto(15)
    static let whisperBodyEmphasis = noto(15, weight: .medium)
    static let whisperControl = noto(14, weight: .medium)
    static let whisperMetadata = noto(13, weight: .medium)
    static let whisperCaption = noto(12)
    static let whisperLabel = noto(11, weight: .medium)
    static let whisperDiaryBody = whisperHandwriting(18)

    static func whisperHandwriting(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Gaegu-Bold" : "Gaegu-Regular", size: size, relativeTo: .body)
    }
}
