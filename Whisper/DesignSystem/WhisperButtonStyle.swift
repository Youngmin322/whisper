//
//  WhisperButtonStyle.swift
//  Whisper
//

import SwiftUI

enum WhisperButtonSize {
    case compact
    case regular

    fileprivate var height: CGFloat {
        switch self {
        case .compact:
            WhisperSize.controlCompact
        case .regular:
            WhisperSize.controlRegular
        }
    }

    fileprivate var cornerRadius: CGFloat {
        switch self {
        case .compact:
            WhisperRadius.medium
        case .regular:
            WhisperRadius.large
        }
    }
}

struct WhisperPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let size: WhisperButtonSize

    init(size: WhisperButtonSize = .regular) {
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.whisperAction)
            .foregroundStyle(Color.whisperTextOnAccent)
            .frame(maxWidth: .infinity, minHeight: size.height)
            .background {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(Color.whisperButtonBackground)
            }
            .opacity(opacity(isPressed: configuration.isPressed))
            .contentShape(.rect)
    }

    private func opacity(isPressed: Bool) -> Double {
        if !isEnabled { return 0.35 }
        return isPressed ? 0.82 : 1
    }
}

struct WhisperSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.whisperControl)
            .foregroundStyle(Color.whisperTextPrimary)
            .frame(minHeight: WhisperSize.controlCompact)
            .padding(.horizontal, WhisperSpacing.medium)
            .background {
                RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
                    .fill(Color.whisperSurfaceSubtle)
                    .overlay {
                        RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
                            .stroke(Color.whisperBorderSubtle, lineWidth: 1)
                    }
            }
            .opacity(opacity(isPressed: configuration.isPressed))
            .contentShape(.rect)
    }

    private func opacity(isPressed: Bool) -> Double {
        if !isEnabled { return 0.35 }
        return isPressed ? 0.72 : 1
    }
}

extension ButtonStyle where Self == WhisperPrimaryButtonStyle {
    static var whisperPrimary: WhisperPrimaryButtonStyle {
        WhisperPrimaryButtonStyle()
    }

    static func whisperPrimary(size: WhisperButtonSize) -> WhisperPrimaryButtonStyle {
        WhisperPrimaryButtonStyle(size: size)
    }
}

extension ButtonStyle where Self == WhisperSecondaryButtonStyle {
    static var whisperSecondary: WhisperSecondaryButtonStyle {
        WhisperSecondaryButtonStyle()
    }
}
