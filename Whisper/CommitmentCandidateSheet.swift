//
//  CommitmentCandidateSheet.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct CommitmentCandidateSheet: View {
    let candidate: CommitmentCandidate
    let onRemember: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sheetContent
            actionBar
        }
        .background(Color.whisperBackground)
        .accessibilityIdentifier("commitment.candidateSheet")
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            Button("응, 간직해줘", action: onRemember)
                .buttonStyle(.whisperPrimary(size: .compact))
                .accessibilityIdentifier("commitment.rememberButton")

            Button("이번에는 괜찮아요", action: onDismiss)
                .font(.whisperControl)
                .foregroundStyle(Color.whisperTextSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                WhisperJar(size: .small)

                VStack(alignment: .leading, spacing: 5) {
                    Text("이 마음을 잠시 간직할까요?")
                        .font(.whisperNavigationTitle)
                        .foregroundStyle(Color.whisperTextPrimary)

                    Text("다시 만나는 날, 그날의 마음을 조용히 다시 건넬게요.")
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(candidate.name)
                    .font(.whisperBodyEmphasis)
                    .foregroundStyle(Color.whisperAccentText)

                Text("“\(candidate.quote)”")
                    .font(.whisperBodyLarge)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .lineSpacing(5)
                    .lineLimit(5)

                if !candidate.topics.isEmpty {
                    Text(candidate.topics.map { "#\($0)" }.joined(separator: "  "))
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperTextSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .whisperCardStyle(
                fill: .whisperSurfaceSubtle,
                border: .whisperBorderSubtle,
                cornerRadius: WhisperRadius.large
            )
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}
