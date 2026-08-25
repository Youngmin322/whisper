//
//  CommitmentCandidateSheet.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

struct CommitmentCandidateSheet: View {
    let candidate: CommitmentCandidate
    let onRemember: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                EmberJar(size: .small)

                VStack(alignment: .leading, spacing: 5) {
                    Text("이 마음을 기억해 둘까요?")
                        .font(.emberNavigationTitle)
                        .foregroundStyle(Color.emberTextPrimary)

                    Text("잊힐 만한 간격으로 Whisper가 다시 건넬게요.")
                        .font(.emberBody)
                        .foregroundStyle(Color.emberTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(candidate.name)
                    .font(.emberBodyEmphasis)
                    .foregroundStyle(Color.emberAccentText)

                Text("“\(candidate.quote)”")
                    .font(.emberBodyLarge)
                    .foregroundStyle(Color.emberTextPrimary)
                    .lineSpacing(5)
                    .lineLimit(5)

                if !candidate.topics.isEmpty {
                    Text(candidate.topics.map { "#\($0)" }.joined(separator: "  "))
                        .font(.emberCaption)
                        .foregroundStyle(Color.emberTextSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .emberCardStyle(
                fill: .emberSurfaceSubtle,
                border: .emberBorderSubtle,
                cornerRadius: EmberRadius.large
            )

            Button("응, 기억해줘", action: onRemember)
                .buttonStyle(.emberPrimary(size: .compact))

            Button("이번에는 괜찮아요", action: onDismiss)
                .font(.emberControl)
                .foregroundStyle(Color.emberTextSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, EmberLayout.sheetHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }
}
