import SwiftUI

/// Use the same quiet, text-only empty states as the iPhone flame home.
struct IPadEmptyState: View {
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: WhisperSpacing.small) {
            Text(title)
                .font(.whisperHandwriting(24))
                .foregroundStyle(Color.whisperTextPrimary)
            if let message {
                Text(message)
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(WhisperSpacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct IPadBottleIcon: View {
    var body: some View {
        Image("BottleLineIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 19, height: 23)
            .accessibilityHidden(true)
    }
}
