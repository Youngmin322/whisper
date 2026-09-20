//
//  Font+Whisper.swift
//  Whisper
//
//  Created by Youngmin Cho on 8/11/26.
//

import SwiftUI

/// Figma specifies Noto Sans KR. The project keeps its bundled Pretendard family
/// here so changing the product typeface later remains a single-file operation.
extension Font {
    /// Figma: Whisper/Brand
    static let whisperBrand = Font.custom(
        "Pretendard-Bold",
        size: 30,
        relativeTo: .largeTitle
    )

    /// Figma: Whisper/Screen Title
    static let whisperScreenTitle = Font.custom(
        "Pretendard-Bold",
        size: 26,
        relativeTo: .title
    )

    static let whisperNavigationTitle = Font.custom(
        "Pretendard-Bold",
        size: 18,
        relativeTo: .headline
    )

    /// Figma: Whisper Current/Sheet Title
    static let whisperSheetTitle = Font.custom(
        "Pretendard-Bold",
        size: 22,
        relativeTo: .title2
    )

    /// Figma: Whisper/Section Title
    static let whisperSectionTitle = Font.custom(
        "Pretendard-Bold",
        size: 17,
        relativeTo: .headline
    )

    static let whisperFieldLabel = Font.custom(
        "Pretendard-Bold",
        size: 16,
        relativeTo: .headline
    )

    static let whisperAction = Font.custom(
        "Pretendard-Bold",
        size: 16,
        relativeTo: .headline
    )

    static let whisperBodyLarge = Font.custom(
        "Pretendard-Regular",
        size: 16,
        relativeTo: .body
    )

    /// Figma: Whisper/Body
    static let whisperBody = Font.custom(
        "Pretendard-Regular",
        size: 15,
        relativeTo: .body
    )

    /// Figma: Whisper/Body Emphasis
    static let whisperBodyEmphasis = Font.custom(
        "Pretendard-Medium",
        size: 15,
        relativeTo: .body
    )

    static let whisperControl = Font.custom(
        "Pretendard-Medium",
        size: 14,
        relativeTo: .callout
    )

    static let whisperMetadata = Font.custom(
        "Pretendard-Medium",
        size: 13,
        relativeTo: .footnote
    )

    /// Figma: Whisper/Caption
    static let whisperCaption = Font.custom(
        "Pretendard-Regular",
        size: 12,
        relativeTo: .caption
    )

    /// Figma: Whisper/Label
    static let whisperLabel = Font.custom(
        "Pretendard-Medium",
        size: 11,
        relativeTo: .caption2
    )
}
