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

    private let contentLimit = 500

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                formContent
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)

            Button(action: save) {
                Text("순간 저장")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.whisperPrimary)
            .disabled(!draft.canSave)
            .accessibilityIdentifier("record.saveButton")
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, WhisperSpacing.small)
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
            HStack(alignment: .center, spacing: WhisperSpacing.medium) {
                Text("순간 남기기")
                    .font(.whisperSheetTitle)
                    .foregroundStyle(Color.whisperTextPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.whisperTextSecondary)
                .accessibilityLabel("닫기")
            }

            Text("지금의 감정이나 있었던 일을 편하게 적어보세요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .padding(.top, WhisperSpacing.xSmall)
                .padding(.bottom, WhisperSpacing.xLarge)

            TextField(
                "무슨 일이 있었나요?",
                text: $draft.content,
                axis: .vertical
            )
            .focused($isContentFocused)
            .font(.whisperBodyLarge)
            .lineSpacing(4)
            .lineLimit(4 ... 8)
            .padding(WhisperSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
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
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, WhisperSpacing.large)
        .padding(.bottom, WhisperSpacing.large)
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
        QuickRecordView(draft: $draft, onSave: { true })
    }
}

#Preview { QuickRecordPreview() }
