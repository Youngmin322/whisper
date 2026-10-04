//
//  Color+Whisper.swift
//  Whisper
//

import SwiftUI

extension Color {
    static let whisperAccent = whisperColor(0xF4523B)
    static let whisperAccentText = whisperColor(0xB64F35)
    // White control text: 5.05:1 normally, 6.82:1 while pressed.
    static let whisperButtonBackground = whisperColor(0xB64F35)
    static let whisperButtonPressedBackground = whisperColor(0x983F2A)

    static let whisperTextPrimary = whisperColor(0x3E3530)
    static let whisperTextSecondary = whisperColor(0x6E6156)
    static let whisperTextOnAccent = whisperColor(0xFFFFFF)

    static let whisperBackground = whisperColor(0xFDFBF6)
    static let whisperSurfaceDefault = whisperColor(0xFFFEFB)
    static let whisperSurfaceElevated = whisperColor(0xFFFFFF)
    static let whisperSurfaceFocus = whisperColor(0xFBF3E9)
    static let whisperSurfaceHighlight = whisperColor(0xF4DCC9)
    static let whisperSurfaceSubtle = whisperColor(0xFBF3E9)

    static let whisperBorderSubtle = whisperColor(0xE5D8CB)
    static let whisperDivider = whisperColor(0xE5D8CB)
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
