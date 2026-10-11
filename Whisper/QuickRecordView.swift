//
//  QuickRecordView.swift
//  Whisper
//

import SwiftUI
import PhotosUI
import UIKit

struct QuickRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Binding var draft: RecordDraft
    @FocusState private var isTitleFocused: Bool
    @State private var isBodyFocused = false
    @ScaledMetric(relativeTo: .body) private var minimumEditorLineHeight: CGFloat = 24
    @State private var isSaveErrorPresented = false
    @State private var isTitleVisible: Bool
    @State private var isPhotoPickerPresented = false
    @State private var isEmotionPickerPresented = false
    @State private var photoLoader: PhotoAttachmentLoader
    @State private var appliedPhotoImportID: UUID?
    @State private var didFinish = false
    @State private var isDraftErrorPresented = false
    @State private var writingHeaderHeight: CGFloat = 44
    @State private var photoInsertionOffset = 0
    @State private var selectedPhoto: DiaryPhoto?
    let draftStore: WritingDraftStore
    let onSave: () -> Bool

    private enum WritingField: Hashable { case content, title }
    private var focusedField: WritingField? {
        get { isTitleFocused ? .title : isBodyFocused ? .content : nil }
        nonmutating set {
            isTitleFocused = newValue == .title
            isBodyFocused = newValue == .content
        }
    }

    init(draft: Binding<RecordDraft>, draftStore: WritingDraftStore,
         photoLoader: PhotoAttachmentLoader? = nil, onSave: @escaping () -> Bool) {
        _draft = draft
        _photoInsertionOffset = State(initialValue: draft.wrappedValue.content.utf16.count)
        self.onSave = onSave
        self.draftStore = draftStore
        _isTitleVisible = State(initialValue: !draft.wrappedValue.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        _photoLoader = State(initialValue: photoLoader ?? PhotoAttachmentLoader())
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if selectedEmotion != nil {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            // Keep the editor's identity and cursor while the keyboard resizes
                            // the page. Very short viewports can scroll the header out of view.
                            writingForm(editorHeight: max(64, minimumEditorLineHeight + 16,
                                                          geometry.size.height - writingHeaderHeight - 24))
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .scrollBounceBehavior(.basedOnSize)
                        .onChange(of: geometry.size.height) { _, _ in
                            if focusedField == .content { scrollProxy.scrollTo("record.contentArea", anchor: .top) }
                            if focusedField == .title { scrollProxy.scrollTo("record.titleArea", anchor: .top) }
                        }
                        .onChange(of: focusedField) { _, field in
                            if field == .content { scrollProxy.scrollTo("record.contentArea", anchor: .top) }
                            if field == .title { scrollProxy.scrollTo("record.titleArea", anchor: .top) }
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
            .navigationTitle(draft.existingRecordID == nil ? "순간 남기기" : "순간 복구")
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
                    Button(draft.existingRecordID == nil ? "저장" : "새 순간으로 저장", action: save)
                        .font(.whisperAction)
                        .tint(Color.whisperAccent)
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                        .accessibilityLabel("순간 저장")
                        .accessibilityIdentifier("record.saveButton")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                writingAccessories
            }
        }
        .task(id: selectedEmotion) {
            guard selectedEmotion != nil, !isEmotionPickerPresented,
                  !isPhotoPickerPresented, !didFinish else { return }
            await Task.yield()
            focusedField = .content
        }
        .sheet(isPresented: $isEmotionPickerPresented, onDismiss: { focusedField = .content }) {
            EmotionPickerView(selectedEmotion: $draft.emotion, allowsEmptySelection: false)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedPhoto) { photo in
            DiaryPhotoViewer(photo: photo, onDelete: { draft.removePhoto(id: photo.id) })
        }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: Binding(
            get: { photoLoader.selectedItems },
            set: { photoLoader.select($0) }
        ), selectionBehavior: .ordered, matching: .images)
        .onChange(of: isPhotoPickerPresented) { _, isPresented in
            if !isPresented && !didFinish { focusedField = .content }
        }
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: photoLoader.completedImport) { _, _ in applyPendingPhotos() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persistDraft() }
        }
        .onDisappear {
            if !didFinish {
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
            recoveryNotice
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
                recoveryNotice
                if draftStore.errorMessage != nil {
                    WritingDraftErrorView(message: draftStore.errorMessage) { persistDraft() }
                }
                writingHeader
                if isTitleVisible { titleField.id("record.titleArea") }
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

    @ViewBuilder
    private var recoveryNotice: some View {
        if draft.existingRecordID != nil {
            Text("원본 순간이 삭제되었어요. 보관한 수정 초안은 오늘의 새 순간으로 저장할 수 있어요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextPrimary)
                .accessibilityIdentifier("record.deletedSourceNotice")
        }
    }

    private var titleField: some View {
        TextField("이 순간의 제목 · 선택 사항", text: $draft.title)
            .font(.whisperHandwriting(28))
            .foregroundStyle(Color.whisperTextPrimary)
            .tint(Color.whisperAccentText)
            .focused($isTitleFocused)
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
                .font(.whisperHandwriting(31))
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
            DiaryTextView(document: Binding(
                get: { draft.diaryDocument },
                set: { value in
                    draft.setDiaryDocument(value)
                }
            ), isFocused: Binding(
                get: { focusedField == .content },
                set: { isBodyFocused = $0 }
            ), fillsHeight: true, minimumHeight: 64,
               placeholder: "기억하고 싶은 순간을 적어보세요.",
               accessibilityIdentifier: "record.contentField",
               onSelectionChange: { photoInsertionOffset = $0 },
               onPhotoTap: { selectedPhoto = $0 })
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

    private var photoButtonLabel: some View {
        HStack(spacing: WhisperSpacing.xxSmall) {
            if photoLoader.isLoading { ProgressView().frame(width: 18) }
            else {
                Image(systemName: draft.photoData == nil ? "photo" : "photo.fill")
                    .resizable().scaledToFit().frame(width: 18, height: 18)
            }
            Text("사진")
        }
        .frame(minWidth: 44, minHeight: 44)
    }

    @ViewBuilder
    private var optionalButtons: some View {
        if selectedEmotion != nil {
            Button { focusedField = nil; isPhotoPickerPresented = true } label: { photoButtonLabel }
            .fixedSize(horizontal: true, vertical: false)
            .disabled(photoLoader.isLoading)
            .accessibilityLabel("사진")
            .accessibilityValue(photoLoader.isLoading ? "불러오는 중" : draft.diaryDocument.photos.isEmpty ? "첨부 없음" : "\(draft.diaryDocument.photos.count)장 첨부됨")
            .accessibilityHint("여러 장의 사진을 선택해 본문에 추가해요.")
            .accessibilityIdentifier("record.photoButton")

            Button {
                isTitleVisible.toggle()
                focusedField = isTitleVisible ? .title : .content
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
            .accessibilityHint(isTitleVisible ? "제목 영역을 접어요." : "본문 위에 제목을 입력해요.")
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
        applyPendingPhotos()
        return draftStore.save(draft)
    }

    private func applyPendingPhotos() {
        guard !didFinish, let result = photoLoader.completedImport, result.id != appliedPhotoImportID else { return }
        appliedPhotoImportID = result.id
        draft.appendPhotos(result.images, at: photoInsertionOffset)
    }

    private func close() {
        guard persistDraft() else { isDraftErrorPresented = true; return }
        didFinish = true
        dismiss()
    }

    private func save() {
        guard draft.canSaveNewMoment && !photoLoader.isLoading else { return }
        applyPendingPhotos()
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
