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
    @Environment(\.scenePhase) private var scenePhase
    @Binding var draft: RecordDraft
    @FocusState private var focusedField: WritingField?
    @State private var isSaveErrorPresented = false
    @State private var optionalSection: OptionalSection?
    @State private var isEmotionPickerPresented = false
    @State private var photoLoader: PhotoAttachmentLoader
    @State private var didFinish = false
    @State private var isDraftErrorPresented = false
    @State private var writingHeaderHeight: CGFloat = 44
    let draftStore: WritingDraftStore
    let onSave: () -> Bool

    private enum WritingField: Hashable { case content, title }
    private enum OptionalSection { case photo, title }

    init(draft: Binding<RecordDraft>, draftStore: WritingDraftStore,
         photoLoader: PhotoAttachmentLoader? = nil, onSave: @escaping () -> Bool) {
        _draft = draft
        self.onSave = onSave
        self.draftStore = draftStore
        _photoLoader = State(initialValue: photoLoader ?? PhotoAttachmentLoader(photoData: draft.wrappedValue.photoData))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if selectedEmotion != nil {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            // Keep the editor's identity and cursor while the keyboard resizes
                            // the page. Very short viewports can scroll the header out of view.
                            writingForm(editorHeight: max(64, geometry.size.height - writingHeaderHeight - 24))
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .scrollBounceBehavior(.basedOnSize)
                        .onChange(of: geometry.size.height) { _, _ in
                            if focusedField == .content { scrollProxy.scrollTo("record.contentArea", anchor: .top) }
                        }
                        .onChange(of: focusedField) { _, field in
                            if field == .content { scrollProxy.scrollTo("record.contentArea", anchor: .top) }
                        }
                    }
                } else {
                    ScrollView {
                        moodForm
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.whisperBackground)
            .navigationTitle("순간 남기기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(Color.whisperTextSecondary)
                    .accessibilityLabel("작성 화면 닫기")
                    .accessibilityHint("작성 중인 초안을 보관해요.")
                    .accessibilityIdentifier("record.closeButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .font(.whisperAction)
                        .tint(Color.whisperAccentText)
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                        .accessibilityLabel("순간 저장")
                        .accessibilityIdentifier("record.saveButton")
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                writingAccessories
            }
        }
        .task(id: selectedEmotion) {
            guard selectedEmotion != nil, !isEmotionPickerPresented,
                  optionalSection != .photo, !didFinish else { return }
            await Task.yield()
            focusedField = .content
        }
        .sheet(isPresented: $isEmotionPickerPresented, onDismiss: { focusedField = .content }) {
            EmotionPickerView(selectedEmotion: $draft.emotion, allowsEmptySelection: false)
                .presentationDetents([.medium, .large])
        }
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: photoLoader.photoData) { _, data in
            if !didFinish { draft.photoData = data }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persistDraft() }
        }
        .onDisappear {
            if !didFinish {
                draft.photoData = photoLoader.photoData
                persistDraft()
            }
            photoLoader.cancelLoading()
        }
        .alert("초안을 보관할 수 없어요", isPresented: $isDraftErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("작성한 내용은 이 화면에 남아 있어요. 임시 저장을 다시 시도해 주세요.")
        }
        .alert("기록을 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("다시 시도", action: save)
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용은 그대로 두었어요. 잠시 후 다시 시도해 주세요.")
        }
        .alert("사진을 불러올 수 없어요", isPresented: Binding(
            get: { photoLoader.errorMessage != nil },
            set: { if !$0 { photoLoader.dismissError() } }
        )) {
            Button("확인", role: .cancel) { photoLoader.dismissError() }
        } message: {
            Text(photoLoader.errorMessage ?? "다른 사진으로 다시 시도해 주세요.")
        }
    }

    private var moodForm: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xLarge) {
            WritingDraftErrorView(message: draftStore.errorMessage) { persistDraft() }
            Text(Date.now.whisperFullDayDescription)
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)

            moodSection
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

    private var canSave: Bool { draft.canSaveNewMoment && !photoLoader.isLoading }

    private func writingForm(editorHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                if draftStore.errorMessage != nil {
                    WritingDraftErrorView(message: draftStore.errorMessage) { persistDraft() }
                }
                writingHeader
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { writingHeaderHeight = $0 }
            writingSection(editorHeight: editorHeight).id("record.contentArea")
        }
        .padding(.horizontal, 26)
        .padding(.top, WhisperSpacing.xSmall)
        .padding(.bottom, WhisperSpacing.xxSmall)
        .frame(maxWidth: 700, alignment: .top)
        .frame(maxWidth: .infinity)
    }

    private var writingHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: WhisperSpacing.small) {
                writingDate.fixedSize()
                Spacer(minLength: WhisperSpacing.xSmall)
                emotionControl
            }
            VStack(alignment: .leading, spacing: 0) {
                writingDate
                HStack { Spacer(); emotionControl }
            }
        }
    }

    private var writingDate: some View {
        Text(Date.now.whisperDayDescription)
            .font(.whisperMetadata)
            .foregroundStyle(Color.whisperTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Date.now.whisperFullDayDescription)
            .accessibilityIdentifier("record.dateLabel")
    }

    private var emotionControl: some View {
        Button {
            focusedField = nil
            isEmotionPickerPresented = true
        } label: {
            HStack(spacing: WhisperSpacing.xxSmall) {
                if let emotion = selectedEmotion {
                    emotionArtwork(emotion, size: 28).accessibilityHidden(true)
                    Text(emotion.rawValue)
                    Image(systemName: "chevron.down")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 8, height: 8)
                }
            }
            .font(.whisperMetadata)
            .foregroundStyle(Color.whisperTextSecondary)
            .frame(minWidth: 44, minHeight: 44)
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("감정 바꾸기, 현재 \(draft.emotion ?? "선택 안 함")")
        .accessibilityIdentifier("record.changeEmotionButton")
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

    private func writingSection(editorHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft.content)
                    .focused($focusedField, equals: .content)
                    .font(.whisperBodyLarge)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .tint(Color.whisperAccentText)
                    .lineSpacing(8)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .padding(.horizontal, -5)
                    .accessibilityLabel("순간 본문")
                    .accessibilityIdentifier("record.contentField")

                if draft.content.isEmpty {
                    Text("기억하고 싶은 순간을 적어보세요.")
                        .font(.whisperBodyLarge)
                        .lineSpacing(8)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: editorHeight)

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

    @ViewBuilder
    private var writingAccessories: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
            if selectedEmotion != nil {
                if optionalSection == .photo {
                    ScrollView {
                        PhotoAttachmentEditor(loader: photoLoader, isCompact: true, showsErrorAlert: false)
                    }
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 100 : 76)
                } else if optionalSection == .title {
                    TextField("이 순간의 제목 · 선택 사항", text: $draft.title)
                        .font(.whisperBodyLarge)
                        .foregroundStyle(Color.whisperTextPrimary)
                        .tint(Color.whisperAccentText)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.done)
                        .onSubmit { focusedField = .content }
                        .padding(.vertical, WhisperSpacing.xSmall)
                        .frame(minHeight: 44)
                        .overlay(alignment: .bottom) {
                            Color.whisperDivider.frame(height: 1)
                        }
                        .accessibilityLabel("순간 제목, 선택 사항")
                        .accessibilityIdentifier("record.titleField")
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: WhisperSpacing.small) {
                    optionalButtons
                    Spacer(minLength: 0)
                    writingOptions
                }
                VStack(spacing: 0) {
                    HStack(spacing: WhisperSpacing.small) { optionalButtons; Spacer(minLength: 0) }
                    HStack { Spacer(minLength: 0); writingOptions }
                }
                VStack(alignment: .leading, spacing: 0) {
                    optionalButtons
                    HStack { Spacer(minLength: 0); writingOptions }
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, WhisperSpacing.xxSmall)
        .padding(.bottom, WhisperSpacing.xxSmall)
        .font(.whisperControl)
        .foregroundStyle(Color.whisperTextSecondary)
        .buttonStyle(.plain)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .background(Color.whisperBackground)
    }

    @ViewBuilder
    private var optionalButtons: some View {
        if selectedEmotion != nil {
            Button {
                optionalSection = optionalSection == .photo ? nil : .photo
                focusedField = optionalSection == nil ? .content : nil
            } label: {
                HStack(spacing: WhisperSpacing.xxSmall) {
                    if photoLoader.isLoading {
                        ProgressView().frame(width: 18)
                    } else {
                        Image(systemName: draft.photoData == nil ? "photo" : "photo.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                    Text("사진")
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("사진")
            .accessibilityValue(photoLoader.isLoading ? "불러오는 중" : draft.photoData == nil ? "첨부 없음" : "1장 첨부됨")
            .accessibilityHint(optionalSection == .photo ? "사진 영역을 접어요." : "사진을 추가하거나 바꿔요.")
            .accessibilityIdentifier("record.photoButton")

            Button {
                optionalSection = optionalSection == .title ? nil : .title
                focusedField = optionalSection == .title ? .title : .content
            } label: {
                HStack(spacing: WhisperSpacing.xxSmall) {
                    Image(systemName: draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "textformat" : "textformat.alt")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("제목")
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityValue(draft.title.isEmpty ? "입력 없음" : draft.title)
            .accessibilityHint(optionalSection == .title ? "제목 영역을 접어요." : "제목을 입력해요.")
            .accessibilityIdentifier("record.titleButton")
        }
    }

    @ViewBuilder
    private var writingOptions: some View {
        if focusedField != nil {
            Button { focusedField = nil } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("키보드 내리기")
            .accessibilityIdentifier("record.dismissKeyboardButton")
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard !didFinish else { return true }
        if draft.photoData != photoLoader.photoData { draft.photoData = photoLoader.photoData }
        return draftStore.save(draft)
    }

    private func close() {
        draft.photoData = photoLoader.photoData
        guard persistDraft() else { isDraftErrorPresented = true; return }
        didFinish = true
        dismiss()
    }

    private func save() {
        guard draft.canSaveNewMoment && !photoLoader.isLoading else { return }
        draft.photoData = photoLoader.photoData
        didFinish = true
        if onSave() {
            dismiss()
        } else {
            didFinish = false
            isSaveErrorPresented = true
        }
    }
}

private struct QuickRecordPreview: View {
    private let store = RecordStore(isStoredInMemoryOnly: true)
    @State private var draft = RecordDraft()

    var body: some View {
        QuickRecordView(draft: $draft, draftStore: store.writingDraftStore, onSave: { true })
    }
}

#Preview { QuickRecordPreview() }
