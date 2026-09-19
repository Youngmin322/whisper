//
//  QuickRecordView.swift
//  Whisper
//

import SwiftUI
import UIKit

struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: RecordDraft
    @FocusState private var isContentFocused: Bool
    @State private var isSaveErrorPresented = false
    @State private var isClipboardLinkUnavailablePresented = false
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
                Text("오늘의 순간 저장")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 25))
            .controlSize(.large)
            .disabled(!draft.canSave)
            .accessibilityIdentifier("record.saveButton")
            .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
            .padding(.top, WhisperSpacing.small)

            Text("저장 후 바로 닫혀요")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .padding(.top, WhisperSpacing.xSmall)
                .padding(.bottom, WhisperSpacing.medium)
        }
        .background(Color.whisperBackground)
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
        .alert("복사한 링크가 없어요", isPresented: $isClipboardLinkUnavailablePresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("링크를 먼저 복사한 뒤 다시 눌러주세요.")
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.large) {
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text("지금 떠오른 순간")
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)

                Text("짧아도, 정리되지 않아도 괜찮아요")
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
            }

            TextField(
                "떠오르는 장면이나 마음을 편하게 적어보세요.",
                text: $draft.content,
                axis: .vertical
            )
            .focused($isContentFocused)
            .font(.whisperBodyLarge)
            .lineSpacing(4)
            .lineLimit(3 ... 5)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            .background(
                Color.whisperSurfaceDefault,
                in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
                    .stroke(Color.whisperBorderSubtle, lineWidth: 1)
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

            HStack(spacing: WhisperSpacing.xSmall) {
                captureModeButton(title: "한 줄", systemImage: "textformat", isSelected: true) {
                    isContentFocused = true
                }
                captureModeButton(title: "사진", systemImage: "photo") {
                    onOpenDetail()
                    dismiss()
                }
                captureModeButton(title: "음성", systemImage: "waveform") {
                    isContentFocused = true
                }
                captureModeButton(title: "링크", systemImage: "link") {
                    pasteLink()
                }
            }
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, WhisperSpacing.large)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func captureModeButton(
        title: String,
        systemImage: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        if isSelected {
            Button(action: action) {
                captureModeLabel(title: title, systemImage: systemImage)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: WhisperRadius.medium))
            .controlSize(.small)
            .accessibilityIdentifier("record.mode.\(title)")
        } else {
            Button(action: action) {
                captureModeLabel(title: title, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: WhisperRadius.medium))
            .controlSize(.small)
            .accessibilityIdentifier("record.mode.\(title)")
        }
    }

    private func captureModeLabel(title: String, systemImage: String) -> some View {
        VStack(spacing: WhisperSpacing.xxSmall) {
            Image(systemName: systemImage)
            Text(title)
                .font(.whisperCaption)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
    }

    private func save() {
        if onSave() {
            dismiss()
        } else {
            isSaveErrorPresented = true
        }
    }

    private func pasteLink() {
        guard let clipboardText = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: clipboardText),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            isClipboardLinkUnavailablePresented = true
            return
        }

        draft.content = String(clipboardText.prefix(contentLimit))
        isContentFocused = true
    }
}

private struct QuickRecordPreview: View {
    @State private var draft = RecordDraft()

    var body: some View {
        QuickRecordView(draft: $draft, onSave: { true }, onOpenDetail: {})
    }
}

#Preview { QuickRecordPreview() }
