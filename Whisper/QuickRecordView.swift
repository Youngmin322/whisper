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
            }
            .safeAreaInset(edge: .bottom) {
                if draft.emotion != nil {
                    Button("순간 저장", action: save)
                        .buttonStyle(.whisperPrimary(size: .compact))
                        .disabled(!draft.canSaveNewMoment || isPhotoLoading)
                        .accessibilityIdentifier("record.saveButton")
                        .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                        .padding(.vertical, WhisperSpacing.xSmall)
                        .background(Color.whisperBackground)
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

            if let emotion = selectedEmotion {
                selectedEmotionSection(emotion)
                writingSection
                detailsDisclosure
            } else {
                moodSection
            }
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, WhisperSpacing.large)
        .padding(.bottom, WhisperSpacing.xxLarge)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
    }

    private var selectedEmotion: WhisperEmotion? {
        WhisperEmotion.allCases.first { $0.rawValue == draft.emotion }
    }

    private func selectedEmotionSection(_ emotion: WhisperEmotion) -> some View {
        HStack(spacing: WhisperSpacing.medium) {
            emotionArtwork(emotion, size: 65)

            VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                Text("지금 마음")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
                Text(emotion.rawValue)
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
            }

            Spacer(minLength: 0)

            Button("감정 바꾸기") {
                isContentFocused = false
                withAnimation(.easeInOut(duration: 0.24)) {
                    draft.emotion = nil
                }
            }
            .font(.whisperMetadata)
            .foregroundStyle(Color.whisperAccentText)
            .frame(minHeight: 44)
            .accessibilityIdentifier("record.changeEmotionButton")
        }
        .padding(.horizontal, WhisperSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 102)
        .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: WhisperRadius.medium)
                .stroke(Color.whisperBorderSubtle, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("지금 내 마음은 어떤가요?")
                .font(.whisperHandwriting(31, bold: true))
                .foregroundStyle(Color.whisperTextPrimary)

            Text("가장 가까운 감정 하나를 골라보세요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .padding(.top, WhisperSpacing.xSmall)

            LazyVGrid(columns: moodColumns, spacing: WhisperSpacing.medium) {
                ForEach(WhisperEmotion.selectableCases) { emotion in
                    moodButton(emotion)
                }
            }
            .padding(.top, 36)

            Text("정확한 이름이 아니어도 괜찮아요.\n지금 가장 먼저 떠오르는 마음을 골라요.")
                .font(.whisperHandwriting(17))
                .foregroundStyle(Color.whisperTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 70)

            Rectangle()
                .fill(Color.whisperDivider)
                .frame(height: 1)
                .padding(.top, 61)

            Text("감정을 고르면 글쓰기 영역이 열려요")
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, WhisperSpacing.medium)
        }
    }

    private var moodColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: WhisperSpacing.xSmall),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
        )
    }

    private func moodButton(_ emotion: WhisperEmotion) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.24)) {
                draft.emotion = emotion.rawValue
            }
        } label: {
            VStack(spacing: WhisperSpacing.xSmall) {
                emotionArtwork(emotion, size: 53)
                    .frame(height: 64)
                Text(emotion.rawValue)
                    .font(.whisperControl)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.whisperTextPrimary)
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 154 : 129)
            .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: WhisperRadius.medium)
                    .stroke(Color.whisperBorderSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(emotion.rawValue)
        .accessibilityHint("선택하면 글쓰기 영역이 열려요.")
        .accessibilityIdentifier("record.emotion.\(emotion.id)")
    }

    private func emotionArtwork(_ emotion: WhisperEmotion, size: CGFloat) -> some View {
        FlameCharacter(emotion: emotion.rawValue, size: size)
    }

    private var writingSection: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text("어떤 순간이었나요?")
                .font(.whisperHandwriting(29, bold: true))
                .foregroundStyle(Color.whisperTextPrimary)

            Text("있는 그대로 한두 문장으로 남겨보세요.")
                .font(.whisperControl)
                .foregroundStyle(Color.whisperTextSecondary)

            TextField("", text: $draft.content, axis: .vertical)
            .focused($isContentFocused)
            .font(.whisperBodyLarge)
            .lineSpacing(4)
            .lineLimit(5 ... 9)
            .padding(WhisperSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
            .overlay(alignment: .topLeading) {
                if draft.content.isEmpty {
                    Text(RecordWritingCopy.contentExample)
                        .font(.whisperBodyLarge)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .padding(WhisperSpacing.medium)
                        .allowsHitTesting(false)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: WhisperRadius.medium)
                    .fill(Color.whisperSurfaceDefault)
                Canvas { context, size in
                    var lines = Path()
                    for y in stride(from: CGFloat(73), through: size.height - 16, by: 47) {
                        lines.move(to: CGPoint(x: 16, y: y))
                        lines.addLine(to: CGPoint(x: size.width - 16, y: y))
                    }
                    context.stroke(lines, with: .color(Color.whisperBorderSubtle), lineWidth: 1)
                }
                .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: WhisperRadius.medium)
                    .stroke(Color.whisperBorderSubtle, lineWidth: 1)
            }
            .accessibilityLabel("기록 내용")
            .accessibilityIdentifier("record.contentField")
            .padding(.top, WhisperSpacing.medium)

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

    private var detailsDisclosure: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            Button {
                isContentFocused = false
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOptionalDetailsExpanded.toggle()
                }
            } label: {
                HStack(spacing: WhisperSpacing.xSmall) {
                    if let photoData = draft.photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "plus")
                            .accessibilityHidden(true)
                    }
                    detailActionCopy
                    Spacer()
                }
                .font(.whisperControl)
                .foregroundStyle(Color.whisperTextSecondary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isOptionalDetailsExpanded ? "사진과 제목 입력을 접어요." : "사진과 제목 입력을 열어요.")
            .accessibilityIdentifier("record.openDetailButton")

            if isOptionalDetailsExpanded {
                optionalDetails
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
        guard draft.canSaveNewMoment && !isPhotoLoading else { return }
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
