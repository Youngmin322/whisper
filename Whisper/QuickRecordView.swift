//
//  QuickRecordView.swift
//  Whisper
//

import SwiftUI
import UIKit
import WhisperDesignSystem

struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var draft: RecordDraft
    @FocusState private var isContentFocused: Bool
    @State private var isSaveErrorPresented = false
    @State private var isDiscardConfirmationPresented = false
    @State private var isOptionalDetailsExpanded = false
    @State private var isPhotoLoading = false
    let onSave: () -> Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                formContent
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.whisperBackground)
            .navigationTitle("순간 남기기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: cancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .disabled(!draft.canSave || isPhotoLoading)
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
        .confirmationDialog(
            "작성 중인 순간을 버릴까요?",
            isPresented: $isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("작성 취소", role: .destructive) {
                draft = RecordDraft()
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 글·제목과 선택한 감정·사진이 삭제돼요.")
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xLarge) {
            Text(Date.now.whisperFullDayDescription)
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)

            moodSection
            writingSection

            DisclosureGroup(isExpanded: $isOptionalDetailsExpanded) {
                optionalDetails
                    .padding(.top, WhisperSpacing.medium)
            } label: {
                HStack(spacing: WhisperSpacing.small) {
                    if let photoData = draft.photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .accessibilityHidden(true)
                    }

                    detailActionCopy
                    Spacer()
                }
                .foregroundStyle(Color.whisperTextPrimary)
                .frame(minHeight: WhisperSize.controlCompact)
            }
            .tint(Color.whisperTextSecondary)
            .padding(WhisperSpacing.medium)
            .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: WhisperRadius.medium)
                    .stroke(Color.whisperBorderSubtle, lineWidth: 1)
            }
            .onChange(of: isOptionalDetailsExpanded) { _, isExpanded in
                if isExpanded { isContentFocused = false }
            }
            .accessibilityIdentifier("record.openDetailButton")
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, WhisperSpacing.large)
        .padding(.bottom, WhisperSpacing.xxLarge)
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text("지금 마음은 어때요?")
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
                Text("감정은 골라도, 건너뛰어도 괜찮아요.")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
            }

            LazyVGrid(columns: moodColumns, spacing: WhisperSpacing.small) {
                ForEach(WhisperEmotion.allCases) { emotion in
                    moodButton(emotion)
                }
            }
        }
    }

    private var moodColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: WhisperSpacing.small),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
        )
    }

    private func moodButton(_ emotion: WhisperEmotion) -> some View {
        let isSelected = draft.emotion == emotion.rawValue
        return Button {
            draft.emotion = isSelected ? nil : emotion.rawValue
        } label: {
            VStack(spacing: WhisperSpacing.xSmall) {
                Text(emotion.emoji)
                    .font(.system(size: 30))
                    .frame(height: 36)
                    .accessibilityHidden(true)
                Text(emotion.rawValue)
                    .font(.whisperControl)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? Color.whisperAccentText : Color.whisperTextPrimary)
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 94 : 76)
            .padding(.vertical, WhisperSpacing.xSmall)
            .background(
                isSelected ? Color.whisperSurfaceHighlight : Color.whisperSurfaceDefault,
                in: RoundedRectangle(cornerRadius: WhisperRadius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WhisperRadius.medium)
                    .stroke(isSelected ? Color.whisperAccent : Color.whisperBorderSubtle, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emotion.rawValue)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
        .accessibilityHint(isSelected ? "다시 누르면 감정 선택이 해제돼요." : "이 감정을 기록에 더해요.")
        .accessibilityIdentifier("record.emotion.\(emotion.id)")
    }

    private var writingSection: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text("기억하고 싶은 장면")
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            TextField(
                RecordWritingCopy.contentExample,
                text: $draft.content,
                axis: .vertical
            )
            .focused($isContentFocused)
            .font(.whisperBodyLarge)
            .lineSpacing(4)
            .lineLimit(5 ... 9)
            .padding(WhisperSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(
                Color.whisperSurfaceDefault,
                in: RoundedRectangle(cornerRadius: WhisperRadius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: WhisperRadius.medium)
                    .stroke(Color.whisperBorderSubtle, lineWidth: 1)
            }
            .accessibilityLabel("기록 내용")
            .accessibilityIdentifier("record.contentField")

            Text("한 문장만 남겨도 돼요. 오늘 일기에 가져올 수 있어요.")
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)

            if draft.content.count >= RecordDraft.contentLimit - 100 {
                Text("\(draft.content.count) / \(RecordDraft.contentLimit.formatted())")
                    .font(.whisperCaption)
                    .foregroundStyle(draft.content.count > RecordDraft.contentLimit ? .red : Color.whisperTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel(
                        "현재 \(draft.content.count)자, 최대 \(RecordDraft.contentLimit)자"
                    )
            }
            if draft.content.count > RecordDraft.contentLimit {
                Text("최대 1,000자까지 저장할 수 있어요. 내용을 줄여 주세요.")
                    .font(.whisperCaption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var optionalDetails: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            PhotoAttachmentEditor(photoData: $draft.photoData) { isLoading in
                isPhotoLoading = isLoading
            }

            Text("제목 · 선택 사항")
                .font(.whisperFieldLabel)
                .foregroundStyle(Color.whisperTextPrimary)
            TextField(RecordWritingCopy.titleExample, text: $draft.title)
                .font(.whisperBodyLarge)
                .padding(.horizontal, WhisperSpacing.medium)
                .frame(minHeight: WhisperSize.controlRegular)
                .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
                .accessibilityIdentifier("record.titleField")
        }
    }

    private var detailActionCopy: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
            Text("사진 · 제목 더하기")
                .font(.whisperControl)
            if visibleDraftTitle != nil || draft.photoData != nil {
                Text(detailSummary)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var visibleDraftTitle: String? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private var detailSummary: String {
        switch (visibleDraftTitle, draft.photoData != nil) {
        case let (title?, true): "\(title) · 사진 1장"
        case let (title?, false): title
        case (nil, true): "사진 1장 첨부됨"
        case (nil, false): ""
        }
    }

    private func cancel() {
        if draft.hasChanges {
            isDiscardConfirmationPresented = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard draft.canSave && !isPhotoLoading else { return }
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
