//
//  Color+Whisper.swift
//  Whisper
//

import SwiftUI
import UIKit

extension Color {
    static let whisperAccent = whisperDynamicColor(
        light: 0xFF4F36,
        dark: 0xFF7A66
    )
    static let whisperAccentText = whisperDynamicColor(
        light: 0xE84B2F,
        dark: 0xFF9A89
    )

    static let whisperTextPrimary = whisperDynamicColor(
        light: 0x202321,
        dark: 0xF5F7F5
    )
    static let whisperTextSecondary = whisperDynamicColor(
        light: 0x6B726E,
        dark: 0xBBC2BD
    )
    static let whisperTextOnAccent = whisperDynamicColor(
        light: 0xFFFFFF,
        dark: 0x2B0B06
    )

    static let whisperBackground = whisperDynamicColor(
        light: 0xFFFFFF,
        dark: 0x111412
    )
    static let whisperSurfaceDefault = whisperDynamicColor(
        light: 0xFFFFFF,
        dark: 0x191D1A
    )
    static let whisperSurfaceElevated = whisperDynamicColor(
        light: 0xFFFFFF,
        dark: 0x222824
    )
    static let whisperSurfaceFocus = whisperDynamicColor(
        light: 0xEEF3F1,
        dark: 0x26302B
    )
    static let whisperSurfaceHighlight = whisperDynamicColor(
        light: 0xFFF1ED,
        dark: 0x33211D
    )
    static let whisperSurfaceSubtle = whisperDynamicColor(
        light: 0xF3F5F4,
        dark: 0x202521
    )

    static let whisperBorderSubtle = whisperDynamicColor(
        light: 0xDCE2DE,
        dark: 0x465049
    )
    static let whisperDivider = whisperDynamicColor(
        light: 0xDCE2DE,
        dark: 0x343C37
    )
    static let whisperScrim = whisperDynamicColor(
        light: 0x2E1F17,
        dark: 0x000000,
        lightAlpha: 0.18,
        darkAlpha: 0.48
    )

    static let whisperFlameOuter = whisperDynamicColor(
        light: 0xFF7442,
        dark: 0xFF8A5C
    )
    static let whisperFlameInner = whisperDynamicColor(
        light: 0xFFD23F,
        dark: 0xFFDC68
    )
}

private func whisperDynamicColor(
    light: UInt32,
    dark: UInt32,
    lightAlpha: CGFloat = 1,
    darkAlpha: CGFloat = 1
) -> Color {
    Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(whisperHex: dark, alpha: darkAlpha)
            } else {
                UIColor(whisperHex: light, alpha: lightAlpha)
            }
        }
    )
}

private extension UIColor {
    convenience init(whisperHex: UInt32, alpha: CGFloat) {
        self.init(
            red: CGFloat((whisperHex >> 16) & 0xFF) / 255,
            green: CGFloat((whisperHex >> 8) & 0xFF) / 255,
            blue: CGFloat(whisperHex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
