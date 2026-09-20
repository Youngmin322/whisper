//
//  WhisperToast.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct WhisperToast: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String = "checkmark.circle.fill") {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.whisperControl)
            .foregroundStyle(Color.whisperTextOnAccent)
            .padding(.horizontal, WhisperSpacing.medium)
            .padding(.vertical, WhisperSpacing.small)
            .background(Color.whisperTextPrimary, in: Capsule())
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 6)
            .accessibilityElement(children: .combine)
    }
}
