//
//  WhisperButtonStyle.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

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
                    .fill(Color.whisperAccent)
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

struct WhisperFilterChip: View {
    let title: String
    let isSelected: Bool
    var showsMenuIndicator = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)

            if showsMenuIndicator {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .font(.whisperControl)
        .foregroundStyle(isSelected ? Color.whisperTextOnAccent : Color.whisperTextPrimary)
        .padding(.horizontal, WhisperSpacing.medium)
        .frame(height: 40)
        .background {
            Capsule()
                .fill(isSelected ? Color.whisperAccent : Color.whisperSurfaceDefault)
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.whisperAccent : Color.whisperBorderSubtle,
                            lineWidth: 1
                        )
                }
        }
        .padding(.vertical, 2)
        .contentShape(.capsule)
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
