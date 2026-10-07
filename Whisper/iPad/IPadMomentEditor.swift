import SwiftUI
import PhotosUI

/// Owns its draft independently of the window layout. The native editor stays in
/// the same view slot when the emotion column is added or removed on resize.
struct IPadMomentEditor: View {
    let recordStore: RecordStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: RecordDraft
    @State private var photoLoader: PhotoAttachmentLoader
    @State private var isBodyFocused = false
    @FocusState private var isTitleFocused: Bool
    @State private var isPhotoPickerPresented = false
    @State private var isEmotionPickerPresented = false
    @State private var selectedPhoto: DiaryPhoto?
    @State private var photoInsertionOffset: Int
    @State private var didFinish = false
    @State private var isSaveErrorPresented = false
    @State private var isDraftErrorPresented = false
    private let original: RecordDraft?

    init(draft: RecordDraft, recordStore: RecordStore) {
        self.recordStore = recordStore
        _draft = State(initialValue: draft)
        _photoLoader = State(initialValue: PhotoAttachmentLoader(photoData: draft.photoData))
        _photoInsertionOffset = State(initialValue: draft.content.utf16.count)
        if let id = draft.existingRecordID, let record = recordStore.record(withID: id) {
            original = RecordDraft(title: record.title, content: record.content, emotion: record.emotion,
                                   photoData: record.photoData, document: recordStore.diaryDocument(for: record).withoutPhotoData,
                                   existingRecordID: record.id)
        } else { original = nil }
    }

    private var isEditingExisting: Bool {
        draft.existingRecordID.flatMap { recordStore.record(withID: $0) } != nil
    }
    private var isRecovering: Bool { draft.existingRecordID != nil && !isEditingExisting }
    private var canSave: Bool { (isEditingExisting ? draft.canSave : draft.canSaveNewMoment) && !photoLoader.isLoading }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let showsContext = IPadWritingLayout.showsContext(width: geometry.size.width, dynamicTypeSize: dynamicTypeSize)
                HStack(spacing: 0) {
                    if showsContext {
                        IPadEmotionChoices(emotion: $draft.emotion)
                            .frame(width: IPadWritingLayout.contextWidth)
                        Divider()
                    }
                    ScrollView {
                        VStack(spacing: WhisperSpacing.large) {
                            if !showsContext && draft.emotion == nil {
                                IPadEmotionChoices(emotion: $draft.emotion, isSidebar: false)
                            }
                            IPadPaper {
                                writingContent(showsEmotionMenu: !showsContext)
                            }
                        }
                        .padding(WhisperSpacing.large)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.basedOnSize)
                    .safeAreaInset(edge: .bottom, spacing: 0) { accessories }
                }
            }
            .background(Color.whisperBackground)
            .navigationTitle(isEditingExisting ? "순간 수정" : isRecovering ? "순간 복구" : "순간 남기기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) { Image(systemName: "xmark") }
                        .accessibilityLabel("작성 화면 닫기")
                        .accessibilityHint("작성 중인 초안을 보관해요.")
                        .accessibilityIdentifier("record.closeButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRecovering ? "새 순간으로 저장" : "저장", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.whisperAccent)
                        .disabled(!canSave)
                        .keyboardShortcut("s", modifiers: .command)
                        .accessibilityIdentifier("record.saveButton")
                }
            }
        }
        .tint(Color.whisperTextSecondary)
        .task(id: draft.emotion) {
            guard draft.emotion != nil, !didFinish else { return }
            await Task.yield()
            isBodyFocused = true
        }
        .sheet(isPresented: $isEmotionPickerPresented) {
            EmotionPickerView(selectedEmotion: $draft.emotion, allowsEmptySelection: false)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedPhoto) { DiaryPhotoViewer(photo: $0) }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: Binding(
            get: { photoLoader.selectedItem }, set: { photoLoader.select($0) }
        ), matching: .images)
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: photoLoader.photoData) { _, data in
            if !didFinish { draft.attachPhoto(data, at: photoInsertionOffset) }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { persistDraft() } }
        .onDisappear {
            persistDraft()
            photoLoader.cancelLoading()
        }
        .alert("초안을 보관할 수 없어요", isPresented: $isDraftErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: { Text("작성한 내용은 화면에 남아 있어요. 임시 저장을 다시 시도해 주세요.") }
        .alert("기록을 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("다시 시도", action: save)
            Button("계속 작성", role: .cancel) {}
        } message: { Text("작성한 내용은 그대로 두었어요. 잠시 후 다시 시도해 주세요.") }
        .alert("사진을 불러올 수 없어요", isPresented: Binding(
            get: { photoLoader.errorMessage != nil }, set: { if !$0 { photoLoader.dismissError() } }
        )) { Button("확인", role: .cancel) { photoLoader.dismissError() } }
        message: { Text(photoLoader.errorMessage ?? "다른 사진으로 다시 시도해 주세요.") }
    }

    private func writingContent(showsEmotionMenu: Bool) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.large) {
            HStack {
                Text(original?.existingRecordID.flatMap { recordStore.record(withID: $0)?.createdAt }?.whisperFullDayDescription
                     ?? Date.now.whisperFullDayDescription)
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
                Spacer(minLength: WhisperSpacing.small)
                if showsEmotionMenu {
                    Button {
                        isBodyFocused = false
                        isTitleFocused = false
                        isEmotionPickerPresented = true
                    } label: {
                        Label(draft.emotion ?? "감정 고르기", systemImage: "chevron.down")
                            .font(.whisperControl)
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("record.changeEmotionButton")
                }
            }
            if isRecovering {
                Text("원본 순간이 삭제되었어요. 이 초안은 오늘의 새 순간으로 저장할 수 있어요.")
                    .font(.whisperBody)
            }
            WritingDraftErrorView(message: recordStore.writingDraftStore.errorMessage) { persistDraft() }
            TextField("이 순간의 제목 · 선택 사항", text: $draft.title, axis: .vertical)
                .font(.whisperHandwriting(28))
                .focused($isTitleFocused)
                .accessibilityIdentifier("record.titleField")
            Divider()
            DiaryTextView(document: Binding(get: { draft.diaryDocument }, set: {
                draft.setDiaryDocument($0)
                if photoLoader.photoData != draft.photoData { photoLoader.replacePhoto(with: draft.photoData) }
            }), isFocused: $isBodyFocused, minimumHeight: 300,
                placeholder: "기억하고 싶은 순간을 적어보세요.", accessibilityIdentifier: "record.contentField",
                onSelectionChange: { photoInsertionOffset = $0 }, onPhotoTap: { selectedPhoto = $0 })
                .disabled(draft.emotion == nil)
            if draft.content.count >= RecordDraft.contentLimit - 100 {
                Text("\(draft.content.count) / \(RecordDraft.contentLimit.formatted())")
                    .font(.whisperCaption)
                    .foregroundStyle(draft.content.count > RecordDraft.contentLimit ? .red : Color.whisperTextSecondary)
            }
            if draft.content.count > RecordDraft.contentLimit {
                Text("최대 1,000자까지 저장할 수 있어요. 내용을 줄여 주세요.")
                    .font(.whisperCaption).foregroundStyle(.red)
            }
        }
        .foregroundStyle(Color.whisperTextPrimary)
    }

    private var accessories: some View {
        HStack(spacing: WhisperSpacing.large) {
            Button {
                isBodyFocused = false
                isTitleFocused = false
                isPhotoPickerPresented = true
            } label: {
                if photoLoader.isLoading { ProgressView() }
                else { Label(draft.photoData == nil ? "사진 붙이기" : "사진 바꾸기", systemImage: "photo") }
            }
            .disabled(draft.emotion == nil || photoLoader.isLoading)
            .accessibilityIdentifier("record.photoButton")
            if draft.photoData != nil {
                Button("사진 삭제", systemImage: "trash", role: .destructive) { photoLoader.replacePhoto(with: nil) }
                    .labelStyle(.iconOnly)
            }
            Spacer(minLength: 0)
            if isBodyFocused || isTitleFocused {
                Button { isBodyFocused = false; isTitleFocused = false } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .accessibilityLabel("키보드 내리기")
                .accessibilityIdentifier("record.dismissKeyboardButton")
            }
        }
        .font(.whisperControl)
        .frame(minHeight: 44)
        .padding(.horizontal, WhisperSpacing.large)
        .frame(maxWidth: IPadWritingLayout.paperWidth)
        .frame(maxWidth: .infinity)
        .padding(.vertical, WhisperSpacing.xSmall)
        .background(Color.whisperBackground)
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard !didFinish else { return true }
        if let original, let originalID = original.existingRecordID,
           draft.title == original.title, draft.content == original.content,
           draft.emotion == original.emotion, draft.photoData == original.photoData,
           draft.diaryDocument.photos.map(\.offset) == original.diaryDocument.photos.map(\.offset) {
            if recordStore.writingDraftStore.momentEditDraft(for: originalID) == nil { return true }
            return recordStore.writingDraftStore.discard(id: draft.id)
        }
        return recordStore.writingDraftStore.save(draft)
    }

    private func close() {
        guard persistDraft() else { isDraftErrorPresented = true; return }
        didFinish = true
        dismiss()
    }

    private func save() {
        guard canSave else { return }
        // Mark completion before publishing, so the draft's onDisappear cannot
        // recreate the row removed by the store's atomic save transaction.
        didFinish = true
        if recordStore.saveMomentDraft(draft, recoveringDeletedMoment: isRecovering) != nil {
            dismiss()
        } else {
            didFinish = false
            isSaveErrorPresented = true
        }
    }
}
