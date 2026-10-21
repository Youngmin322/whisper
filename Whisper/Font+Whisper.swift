//
//  Font+Whisper.swift
//  Whisper
//
//  Created by Youngmin Cho on 8/11/26.
//

import SwiftUI

enum WhisperTypography {
    static let handwritingFontName = "KyoboHandwriting2019"
    static let diaryBodySize: CGFloat = 18
}

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
    static let whisperDiaryBody = whisperHandwriting(WhisperTypography.diaryBodySize)

    // Preserve the distinct styles that previously lived in WhisperDesignSystem.
    static let whisperTitle = Font.custom("Pretendard-SemiBold", size: 24)
    static let whisperHeadline = Font.custom("Pretendard-SemiBold", size: 18)
    static let whisperSubheadline = Font.custom("Pretendard-Regular", size: 15)
    static let whisperButton = Font.custom("Pretendard-SemiBold", size: 16)

    static func whisperHandwriting(_ size: CGFloat) -> Font {
        .custom(WhisperTypography.handwritingFontName, size: size, relativeTo: .body)
    }
}
