//
//  Font+Whisper.swift
//  WhisperDesignSystem
//
//  Created by Youngmin Cho on 8/20/26.
//

import SwiftUI
import CoreText

// MARK: - Font Registration

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
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "otf"
        ) else {
            continue
        }

        CTFontManagerRegisterFontsForURL(
            url as CFURL,
            .process,
            nil
        )
    }
}()

public enum WhisperFont {
    /// Registers the Pretendard font files bundled with WhisperDesignSystem.
    public static func register() {
        _ = registerPretendardFonts
    }
}

// MARK: - Whisper Typography

public extension Font {

    /// 화면의 가장 큰 제목
    static let whisperScreenTitle: Font = {
        _ = registerPretendardFonts
        return .custom("Pretendard-Bold", size: 32)
    }()

    /// 주요 섹션 제목
    static let whisperTitle: Font = {
        _ = registerPretendardFonts
        return .custom("Pretendard-SemiBold", size: 24)
    }()

    /// 카드나 컴포넌트의 제목
    static let whisperHeadline: Font = {
        _ = registerPretendardFonts
        return .custom("Pretendard-SemiBold", size: 18)
    }()

    /// 일반 본문
    static let whisperBody: Font = {
        _ = registerPretendardFonts
        return .custom("Pretendard-Regular", size: 16)
    }()

    /// 보조 본문
    static let whisperSubheadline: Font = {
        _ = registerPretendardFonts
        return .custom("Pretendard-Regular", size: 15)
    }()

    /// 작은 설명이나 부가 정보
    static let whisperCaption: Font = {
        _ = registerPretendardFonts
        return .custom("Pretendard-Regular", size: 14)
    }()

    /// 버튼 텍스트
    static let whisperButton: Font = {
        _ = registerPretendardFonts
        return .custom("Pretendard-SemiBold", size: 16)
    }()
}
