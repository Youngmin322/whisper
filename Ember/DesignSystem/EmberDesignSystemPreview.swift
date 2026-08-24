//
//  EmberDesignSystemPreview.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

private struct EmberDesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EmberSpacing.xLarge) {
                typography
                colors
                components
            }
            .padding(.horizontal, EmberLayout.screenHorizontalPadding)
            .padding(.vertical, EmberSpacing.xLarge)
        }
        .background(Color.emberBackground.ignoresSafeArea())
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: EmberSpacing.small) {
            Text("Typography")
                .font(.emberScreenTitle)

            Group {
                Text("오늘의 기록").font(.emberScreenTitle)
                Text("이번 주 기록").font(.emberSectionTitle)
                Text("한 문장만 적어도 충분해요").font(.emberBody)
                Text("FocusMode 연결 가능").font(.emberLabel)
                Text("2026년 8월 14일 · 금요일").font(.emberMetadata)
            }
            .foregroundStyle(Color.emberTextPrimary)
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: EmberSpacing.small) {
            Text("Colors")
                .font(.emberSectionTitle)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96))],
                spacing: EmberSpacing.medium
            ) {
                swatch("Accent", .emberAccent)
                swatch("Warm", .emberSurfaceHighlight)
                swatch("Subtle", .emberSurfaceSubtle)
                swatch("Focus", .emberSurfaceFocus)
                swatch("Text", .emberTextPrimary)
                swatch("Border", .emberBorderSubtle)
            }
        }
    }

    private var components: some View {
        VStack(alignment: .leading, spacing: EmberSpacing.medium) {
            Text("Components")
                .font(.emberSectionTitle)

            VStack(alignment: .leading, spacing: EmberSpacing.xSmall) {
                Text("오늘 다시 만난 불꽃")
                    .font(.emberLabel)
                    .foregroundStyle(Color.emberAccentText)
                Text("첫 기록이 쌓이면 이곳에 나타나요")
                    .font(.emberSectionTitle)
                    .foregroundStyle(Color.emberTextPrimary)
            }
            .padding(EmberSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .emberCardStyle(
                fill: .emberSurfaceSubtle,
                border: .emberBorderSubtle,
                hasShadow: true
            )

            Button("기록 저장하기") {}
                .buttonStyle(.emberPrimary)

            Button("상세 기록으로 이어쓰기") {}
                .buttonStyle(.emberSecondary)
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: EmberSpacing.xSmall) {
            RoundedRectangle(cornerRadius: EmberRadius.small, style: .continuous)
                .fill(color)
                .frame(height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: EmberRadius.small, style: .continuous)
                        .stroke(Color.emberBorderSubtle, lineWidth: 1)
                }

            Text(name)
                .font(.emberCaption)
                .foregroundStyle(Color.emberTextSecondary)
        }
    }
}

#Preview("Ember Design System") {
    EmberDesignSystemPreview()
}
