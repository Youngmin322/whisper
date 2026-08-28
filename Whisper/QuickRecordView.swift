//
//  QuickRecordView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: RecordDraft
    @State private var isSaveErrorPresented = false
    let onSave: () -> Bool
    let onOpenDetail: () -> Void
    private let contentLimit = 280

    var body: some View {
        NavigationStack {
            ScrollView {
                formContent
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("빠르게 기록하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(!draft.canSave)
                        .accessibilityIdentifier("record.saveButton")
                }
            }
        }
        .alert("기록을 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("다시 시도", action: save)
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용은 그대로 두었어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("나중에 다시 만났을 때 떠오를 만큼만 적어도 괜찮아요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(RecordWritingCopy.titleLabel)
                    .font(.whisperFieldLabel)
                    .foregroundStyle(Color.whisperTextPrimary)

                TextField(RecordWritingCopy.titleExample, text: $draft.title)
                    .font(.whisperBodyLarge)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
                    .accessibilityIdentifier("record.titleField")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(RecordWritingCopy.contentLabel)
                    .font(.whisperFieldLabel)
                    .foregroundStyle(Color.whisperTextPrimary)

                ZStack(alignment: .bottomTrailing) {
                    TextField(RecordWritingCopy.contentExample, text: $draft.content, axis: .vertical)
                        .font(.whisperBodyLarge)
                        .lineLimit(3 ... 4)
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                        .onChange(of: draft.content) { _, newValue in
                            guard newValue.count > contentLimit else { return }
                            draft.content = String(newValue.prefix(contentLimit))
                        }
                        .accessibilityIdentifier("record.contentField")

                    Text("\(draft.content.count) / \(contentLimit)")
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .padding(14)
                }
                .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
            }

            Button {
                onOpenDetail()
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("자세히 기록하기").font(.whisperControl)
                    Text("감정과 사진까지 함께 남길 수 있어요").font(.whisperCaption).foregroundStyle(Color.whisperTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 58)
                .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
                .overlay(alignment: .trailing) { Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.whisperTextSecondary).padding(.trailing, 16) }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 20)
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
