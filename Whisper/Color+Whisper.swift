//
//  Color+Whisper.swift
//  Whisper
//

import SwiftUI

extension Color {
    static let whisperAccent = whisperColor(0xC94027)
    static let whisperAccentText = whisperColor(0xB63D27)

    static let whisperTextPrimary = whisperColor(0x202321)
    static let whisperTextSecondary = whisperColor(0x6B726E)
    static let whisperTextOnAccent = whisperColor(0xFFFFFF)

    static let whisperBackground = whisperColor(0xFFFFFF)
    static let whisperSurfaceDefault = whisperColor(0xFFFFFF)
    static let whisperSurfaceElevated = whisperColor(0xFFFFFF)
    static let whisperSurfaceFocus = whisperColor(0xEEF3F1)
    static let whisperSurfaceHighlight = whisperColor(0xFFF1ED)
    static let whisperSurfaceSubtle = whisperColor(0xF3F5F4)

    static let whisperBorderSubtle = whisperColor(0xDCE2DE)
    static let whisperDivider = whisperColor(0xDCE2DE)
    static let whisperScrim = whisperColor(0x2E1F17, alpha: 0.18)

    static let whisperFlameOuter = whisperColor(0xFF7442)
    static let whisperFlameInner = whisperColor(0xFFD23F)
}

private func whisperColor(
    _ hex: UInt32,
    alpha: Double = 1
) -> Color {
    Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255,
        opacity: alpha
    )
}
