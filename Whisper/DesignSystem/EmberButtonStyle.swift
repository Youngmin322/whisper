//
//  EmberButtonStyle.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

enum EmberButtonSize {
    case compact
    case regular

    fileprivate var height: CGFloat {
        switch self {
        case .compact:
            EmberSize.controlCompact
        case .regular:
            EmberSize.controlRegular
        }
    }

    fileprivate var cornerRadius: CGFloat {
        switch self {
        case .compact:
            EmberRadius.medium
        case .regular:
            EmberRadius.large
        }
    }
}

struct EmberPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let size: EmberButtonSize

    init(size: EmberButtonSize = .regular) {
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.emberAction)
            .foregroundStyle(Color.emberTextOnAccent)
            .frame(maxWidth: .infinity, minHeight: size.height)
            .background {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(Color.emberAccent)
            }
            .opacity(opacity(isPressed: configuration.isPressed))
            .contentShape(.rect)
    }

    private func opacity(isPressed: Bool) -> Double {
        if !isEnabled { return 0.35 }
        return isPressed ? 0.82 : 1
    }
}

struct EmberSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.emberControl)
            .foregroundStyle(Color.emberTextPrimary)
            .frame(minHeight: EmberSize.controlCompact)
            .padding(.horizontal, EmberSpacing.medium)
            .background {
                RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous)
                    .fill(Color.emberSurfaceSubtle)
                    .overlay {
                        RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous)
                            .stroke(Color.emberBorderSubtle, lineWidth: 1)
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

extension ButtonStyle where Self == EmberPrimaryButtonStyle {
    static var emberPrimary: EmberPrimaryButtonStyle {
        EmberPrimaryButtonStyle()
    }

    static func emberPrimary(size: EmberButtonSize) -> EmberPrimaryButtonStyle {
        EmberPrimaryButtonStyle(size: size)
    }
}

extension ButtonStyle where Self == EmberSecondaryButtonStyle {
    static var emberSecondary: EmberSecondaryButtonStyle {
        EmberSecondaryButtonStyle()
    }
}
