//
//  QuickRecordView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: RecordDraft
    @FocusState private var isContentFocused: Bool
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
            .background(Color.whisperBackground)
            .navigationTitle("기록하기")
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
            .task {
                await Task.yield()
                isContentFocused = true
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
        VStack(alignment: .leading, spacing: WhisperSpacing.xLarge) {
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text("지금 마음에 남은 건 무엇인가요?")
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)

                Text("한 문장만 적어도 괜찮아요.")
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)

                TextField(
                    "떠오르는 장면이나 마음을 편하게 적어보세요.",
                    text: $draft.content,
                    axis: .vertical
                )
                .focused($isContentFocused)
                .font(.whisperBodyLarge)
                .lineSpacing(4)
                .lineLimit(5 ... 7)
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
                .background(
                    Color.whisperSurfaceSubtle,
                    in: RoundedRectangle(
                        cornerRadius: WhisperRadius.medium,
                        style: .continuous
                    )
                )
                .onChange(of: draft.content) { _, newValue in
                    guard newValue.count > contentLimit else { return }
                    draft.content = String(newValue.prefix(contentLimit))
                }
                .accessibilityLabel("기록 내용")
                .accessibilityIdentifier("record.contentField")

                if shouldShowContentCount {
                    Text("\(draft.content.count) / \(contentLimit)")
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .transition(.opacity)
                        .accessibilityLabel(
                            "현재 \(draft.content.count)자, 최대 \(contentLimit)자"
                        )
                }
            }

            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text("지금의 감정 · 선택")
                    .font(.whisperFieldLabel)
                    .foregroundStyle(Color.whisperTextPrimary)

                Menu {
                    Button("선택 안 함", systemImage: "circle.dashed") {
                        draft.emotion = nil
                    }
                    ForEach(WhisperEmotion.allCases) { emotion in
                        Button(emotion.rawValue, systemImage: emotion.systemImage) {
                            draft.emotion = emotion.rawValue
                        }
                    }
                } label: {
                    HStack {
                        Label(draft.emotion ?? "감정 고르기", systemImage: "face.smiling")
                            .font(.whisperBodyEmphasis)
                            .foregroundStyle(Color.whisperTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.whisperTextSecondary)
                    }
                    .padding(.horizontal, WhisperSpacing.medium)
                    .frame(minHeight: WhisperSize.controlRegular)
                    .background(
                        Color.whisperSurfaceSubtle,
                        in: RoundedRectangle(cornerRadius: WhisperRadius.medium)
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                onOpenDetail()
                dismiss()
            } label: {
                HStack(spacing: WhisperSpacing.small) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .accessibilityHidden(true)

                    detailActionCopy

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.whisperTextSecondary)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.whisperTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, WhisperSpacing.xSmall)
                .frame(minHeight: WhisperSize.controlCompact)
                .background(
                    Color.whisperSurfaceDefault,
                    in: RoundedRectangle(
                        cornerRadius: WhisperRadius.medium,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: WhisperRadius.medium,
                        style: .continuous
                    )
                    .stroke(Color.whisperBorderSubtle, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(detailActionAccessibilityLabel)
            .accessibilityHint("제목, 감정, 사진을 추가할 수 있는 상세 기록 화면으로 이동합니다.")
            .accessibilityIdentifier("record.openDetailButton")
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, WhisperSpacing.large)
        .padding(.bottom, 20)
    }

    private var shouldShowContentCount: Bool {
        draft.content.count >= contentLimit - 40
    }

    @ViewBuilder
    private var detailActionCopy: some View {
        if let visibleDraftTitle {
            VStack(alignment: .leading, spacing: 2) {
                Text(visibleDraftTitle)
                    .font(.whisperControl)
                    .lineLimit(1)

                Text("제목 · 감정 · 사진 편집")
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
        } else {
            Text("제목 · 감정 · 사진도 남기기")
                .font(.whisperControl)
        }
    }

    private var visibleDraftTitle: String? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private var detailActionAccessibilityLabel: String {
        if let visibleDraftTitle {
            return "제목 \(visibleDraftTitle), 감정과 사진 편집"
        }
        return "제목, 감정, 사진도 남기기"
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
