//
//  WhisperDesignSystemPreview.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

private struct WhisperDesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WhisperSpacing.xLarge) {
                typography
                colors
                components
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.vertical, WhisperSpacing.xLarge)
        }
        .background(Color.whisperBackground.ignoresSafeArea())
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text("Typography")
                .font(.whisperScreenTitle)

            Group {
                Text("오늘의 기록").font(.whisperScreenTitle)
                Text("이번 주 기록").font(.whisperSectionTitle)
                Text("한 문장만 적어도 충분해요").font(.whisperBody)
                Text("FocusMode 연결 가능").font(.whisperLabel)
                Text("2026년 8월 14일 · 금요일").font(.whisperMetadata)
            }
            .foregroundStyle(Color.whisperTextPrimary)
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text("Colors")
                .font(.whisperSectionTitle)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96))],
                spacing: WhisperSpacing.medium
            ) {
                swatch("Accent", .whisperAccent)
                swatch("Warm", .whisperSurfaceHighlight)
                swatch("Subtle", .whisperSurfaceSubtle)
                swatch("Focus", .whisperSurfaceFocus)
                swatch("Text", .whisperTextPrimary)
                swatch("Border", .whisperBorderSubtle)
            }
        }
    }

    private var components: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            Text("Components")
                .font(.whisperSectionTitle)

            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text("오늘 다시 만난 불꽃")
                    .font(.whisperLabel)
                    .foregroundStyle(Color.whisperAccentText)
                Text("첫 기록이 쌓이면 이곳에 나타나요")
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
            }
            .padding(WhisperSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .whisperCardStyle(
                fill: .whisperSurfaceSubtle,
                border: .whisperBorderSubtle,
                hasShadow: true
            )

            Button("기록 저장하기") {}
                .buttonStyle(.whisperPrimary)

            Button("상세 기록으로 이어쓰기") {}
                .buttonStyle(.whisperSecondary)
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
            RoundedRectangle(cornerRadius: WhisperRadius.small, style: .continuous)
                .fill(color)
                .frame(height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: WhisperRadius.small, style: .continuous)
                        .stroke(Color.whisperBorderSubtle, lineWidth: 1)
                }

            Text(name)
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
        }
    }
}

#Preview("Whisper Design System") {
    WhisperDesignSystemPreview()
}
