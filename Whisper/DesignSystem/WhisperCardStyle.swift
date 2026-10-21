//
//  WhisperCardStyle.swift
//  Whisper
//

import SwiftUI

private struct WhisperCardModifier: ViewModifier {
    let fill: Color
    let border: Color
    let cornerRadius: CGFloat
    let hasShadow: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    }
                    .shadow(
                        color: hasShadow
                            ? Color(red: 94 / 255, green: 56 / 255, blue: 36 / 255)
                                .opacity(0.08)
                            : .clear,
                        radius: hasShadow ? 24 : 0,
                        x: 0,
                        y: hasShadow ? 8 : 0
                    )
            }
    }
}

extension View {
    func whisperCardStyle(
        fill: Color = .whisperSurfaceDefault,
        border: Color = .clear,
        cornerRadius: CGFloat = WhisperRadius.card,
        hasShadow: Bool = false
    ) -> some View {
        modifier(
            WhisperCardModifier(
                fill: fill,
                border: border,
                cornerRadius: cornerRadius,
                hasShadow: hasShadow
            )
        )
    }
}
