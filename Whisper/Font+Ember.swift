//
//  Font+Ember.swift
//  Ember
//
//  Created by Youngmin Cho on 8/11/26.
//

import SwiftUI

/// Figma specifies Noto Sans KR. The project keeps its bundled Pretendard family
/// here so changing the product typeface later remains a single-file operation.
extension Font {
    /// Figma: Ember/Brand
    static let emberBrand = Font.custom(
        "Pretendard-Bold",
        size: 30,
        relativeTo: .largeTitle
    )

    /// Figma: Ember/Screen Title
    static let emberScreenTitle = Font.custom(
        "Pretendard-Bold",
        size: 26,
        relativeTo: .title
    )

    static let emberNavigationTitle = Font.custom(
        "Pretendard-Bold",
        size: 18,
        relativeTo: .headline
    )

    /// Figma: Ember/Section Title
    static let emberSectionTitle = Font.custom(
        "Pretendard-Bold",
        size: 17,
        relativeTo: .headline
    )

    static let emberFieldLabel = Font.custom(
        "Pretendard-Bold",
        size: 16,
        relativeTo: .headline
    )

    static let emberAction = Font.custom(
        "Pretendard-Bold",
        size: 16,
        relativeTo: .headline
    )

    static let emberBodyLarge = Font.custom(
        "Pretendard-Regular",
        size: 16,
        relativeTo: .body
    )

    /// Figma: Ember/Body
    static let emberBody = Font.custom(
        "Pretendard-Regular",
        size: 15,
        relativeTo: .body
    )

    /// Figma: Ember/Body Emphasis
    static let emberBodyEmphasis = Font.custom(
        "Pretendard-Medium",
        size: 15,
        relativeTo: .body
    )

    static let emberControl = Font.custom(
        "Pretendard-Medium",
        size: 14,
        relativeTo: .callout
    )

    static let emberMetadata = Font.custom(
        "Pretendard-Medium",
        size: 13,
        relativeTo: .footnote
    )

    /// Figma: Ember/Caption
    static let emberCaption = Font.custom(
        "Pretendard-Regular",
        size: 12,
        relativeTo: .caption
    )

    /// Figma: Ember/Label
    static let emberLabel = Font.custom(
        "Pretendard-Medium",
        size: 11,
        relativeTo: .caption2
    )
}
