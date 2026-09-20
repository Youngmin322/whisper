//
//  QuickRecordView.swift
//  Whisper
//

import SwiftUI

struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: RecordDraft
    @FocusState private var isContentFocused: Bool
    @State private var isSaveErrorPresented = false

    let onSave: () -> Bool
    let onOpenDetail: () -> Void

    private let contentLimit = 120

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                formContent
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)

            Button(action: save) {
                Text("오늘에 담기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.whisperPrimary)
            .disabled(!draft.canSave)
            .accessibilityIdentifier("record.saveButton")
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, WhisperSpacing.small)

            Text("사진은 선택 사항이에요")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .padding(.top, WhisperSpacing.xSmall)
                .padding(.bottom, WhisperSpacing.medium)
        }
        .background(Color.whisperBackground.ignoresSafeArea())
        .task {
            await Task.yield()
            isContentFocused = true
        }
        .alert("기록을 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("다시 시도", action: save)
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용은 그대로 두었어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text("지금 떠오른 순간")
                    .font(.whisperSheetTitle)
                    .foregroundStyle(Color.whisperTextPrimary)

                Text("완성된 문장보다 지금의 느낌을 먼저 남겨보세요.")
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
            .padding(.bottom, WhisperSpacing.xxLarge)

            TextField(
                "지금 떠오른 장면이나 마음을 적어보세요.",
                text: $draft.content,
                axis: .vertical
            )
            .focused($isContentFocused)
            .font(.whisperBodyLarge)
            .lineSpacing(4)
            .lineLimit(1 ... 3)
            .padding(WhisperSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            .background(
                isContentFocused ? Color.whisperSurfaceFocus : Color.whisperSurfaceDefault,
                in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
                    .stroke(
                        isContentFocused ? Color.whisperAccent : Color.whisperBorderSubtle,
                        lineWidth: isContentFocused ? 2 : 1
                    )
            }
            .onChange(of: draft.content) { _, newValue in
                guard newValue.count > contentLimit else { return }
                draft.content = String(newValue.prefix(contentLimit))
            }
            .accessibilityLabel("기록 내용")
            .accessibilityIdentifier("record.contentField")

            Text("\(draft.content.count) / \(contentLimit)")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .accessibilityLabel("현재 \(draft.content.count)자, 최대 \(contentLimit)자")
                .padding(.horizontal, WhisperSpacing.medium)
                .padding(.top, WhisperSpacing.xSmall)

            Text("기록 방식")
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)
                .padding(.top, WhisperSpacing.xLarge)
                .padding(.bottom, WhisperSpacing.small)

            HStack(spacing: WhisperSpacing.xSmall) {
                captureModeButton(title: "텍스트", isSelected: true, identifier: "text") {
                    isContentFocused = true
                }

                captureModeButton(title: "사진", identifier: "photo") {
                    onOpenDetail()
                    dismiss()
                }
            }

            Text("저장하면 타임라인에 쌓이고 바로 닫혀요")
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(.horizontal, WhisperSpacing.medium)
                .background(
                    Color.whisperSurfaceHighlight,
                    in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
                )
                .padding(.top, WhisperSpacing.xLarge)
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, WhisperSpacing.large)
        .padding(.bottom, WhisperSpacing.large)
    }

    private func captureModeButton(
        title: String,
        isSelected: Bool = false,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            WhisperFilterChip(title: title, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("record.mode.\(identifier)")
    }

    private func save() {
        if onSave() {
            dismiss()
        } else {
            isSaveErrorPresented = true
        }
    }
}

private struct QuickRecordPreview: View {
    @State private var draft = RecordDraft()

    var body: some View {
        QuickRecordView(draft: $draft, onSave: { true }, onOpenDetail: {})
    }
}

#Preview { QuickRecordPreview() }
