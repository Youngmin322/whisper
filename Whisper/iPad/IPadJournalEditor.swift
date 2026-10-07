import SwiftUI

struct IPadJournalEditor: View {
    let recordStore: RecordStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: JournalWritingDraft
    @State private var recoveryDate: Date
    @State private var isBodyFocused = false
    @State private var selectedPhoto: DiaryPhoto?
    @State private var isSaveErrorPresented = false
    @State private var isDraftErrorPresented = false
    @State private var isDiscardConfirmationPresented = false
    @State private var didFinish = false

    init(draft: JournalWritingDraft, recordStore: RecordStore) {
        self.recordStore = recordStore
        _draft = State(initialValue: IPadDraftPreparation.journal(draft, store: recordStore))
        _recoveryDate = State(initialValue: draft.day.date)
    }

    private var isOriginalDeleted: Bool {
        draft.existingJournalID.map { id in !recordStore.journals.contains { $0.id == id } } ?? false
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let showsContext = IPadWritingLayout.showsContext(width: geometry.size.width, dynamicTypeSize: dynamicTypeSize)
                    && !draft.sourceRecordIDs.isEmpty
                HStack(spacing: 0) {
                    if showsContext {
                        sourceColumn
                            .frame(width: IPadWritingLayout.contextWidth)
                        Divider()
                    }
                    ScrollView {
                        IPadPaper {
                            VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                                header
                                WritingDraftErrorView(message: recordStore.writingDraftStore.errorMessage) { persistDraft() }
                                if isOriginalDeleted { recoveryNotice }
                                DiaryTextView(document: Binding(
                                    get: { draft.document ?? DiaryDocument(text: draft.body) },
                                    set: { draft.document = $0; draft.body = $0.text }
                                ), isFocused: $isBodyFocused, minimumHeight: 360, showsRules: true,
                                   placeholder: "오늘을 돌아보며 적어보세요.", accessibilityIdentifier: "journal.bodyField",
                                   onPhotoTap: { selectedPhoto = $0 })
                                if !showsContext {
                                    DiarySourcesView(ids: draft.sourceRecordIDs, recordStore: recordStore)
                                }
                            }
                        }
                        .padding(WhisperSpacing.large)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .background(Color.whisperBackground)
            .navigationTitle("나의 하루")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) { Image(systemName: "xmark") }
                        .accessibilityLabel("일기 작성 닫기")
                        .accessibilityHint("작성 중인 초안을 보관해요.")
                        .accessibilityIdentifier("journal.closeButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { isDiscardConfirmationPresented = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("초안 삭제")
                        .accessibilityIdentifier("journal.discardDraftButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isOriginalDeleted ? "새 일기로 저장" : "저장", action: save)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut("s", modifiers: .command)
                        .accessibilityIdentifier("journal.saveButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { isBodyFocused = false } label: { Image(systemName: "keyboard.chevron.compact.down") }
                        .accessibilityLabel("키보드 내리기")
                }
            }
        }
        .tint(Color.whisperAccent)
        .sheet(item: $selectedPhoto) { DiaryPhotoViewer(photo: $0) }
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { persistDraft() } }
        .onDisappear { persistDraft() }
        .confirmationDialog("작성 중인 일기 초안을 삭제할까요?", isPresented: $isDiscardConfirmationPresented, titleVisibility: .visible) {
            Button("초안 삭제", role: .destructive) {
                guard recordStore.writingDraftStore.discard(id: draft.id) else { isDraftErrorPresented = true; return }
                didFinish = true
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: { Text("이미 저장한 일기와 원본 순간은 그대로 남아요.") }
        .alert("초안을 보관할 수 없어요", isPresented: $isDraftErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: { Text("작성한 내용은 이 화면에 남아 있어요. 임시 저장을 다시 시도해 주세요.") }
        .alert("일기를 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: { Text(recordStore.journalDraftSaveFailure?.message ?? JournalDraftSaveFailure.storageFailure.message) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.large) {
            HStack {
                Text(draft.day.fullDescription)
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
                Spacer(minLength: WhisperSpacing.small)
                Menu {
                    ForEach(WhisperEmotion.selectableCases) { emotion in
                        Button(emotion.rawValue) { draft.representativeEmotion = emotion.rawValue }
                    }
                } label: {
                    FlameCharacter(emotion: draft.representativeEmotion, size: 38)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("대표 감정 바꾸기, 현재 \(draft.representativeEmotion ?? "선택 안 함")")
            }
            TextField("이 하루의 제목 · 선택 사항", text: $draft.title, axis: .vertical)
                .font(.whisperHandwriting(28))
                .accessibilityIdentifier("journal.titleField")
            Divider()
        }
        .foregroundStyle(Color.whisperTextPrimary)
    }

    private var recoveryNotice: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text("원본 일기가 삭제되었어요").font(.whisperAction)
            Text("날짜를 선택해 이 초안을 새 일기로 저장할 수 있어요.").font(.whisperBody)
            DatePicker("복구할 날짜", selection: $recoveryDate, displayedComponents: .date)
                .environment(\.calendar, draft.day.calendar)
                .environment(\.timeZone, draft.day.calendar.timeZone)
                .accessibilityIdentifier("journal.recoveryDatePicker")
        }
    }

    private var sourceColumn: some View {
        List {
            Section {
                Text("원본을 참고하며 한 편의 일기를 써보세요.")
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
            Section("담아 둔 순간 · \(draft.sourceRecordIDs.count)개") {
                ForEach(draft.sourceRecordIDs, id: \.self) { id in
                    if let record = recordStore.record(withID: id) {
                        NavigationLink {
                            RecordDetailView(record: record, recordStore: recordStore)
                        } label: {
                            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                                Text(record.createdAt.whisperDateTimeDescription).font(.whisperMetadata)
                                    .foregroundStyle(Color.whisperTextSecondary)
                                Text(record.title).font(.whisperHandwriting(22))
                                Text(record.content).font(.whisperDiaryBody).lineLimit(3)
                                    .foregroundStyle(Color.whisperTextSecondary)
                            }
                            .padding(.vertical, WhisperSpacing.small)
                        }
                        .accessibilityIdentifier("ipad.journal.source.\(id)")
                    } else {
                        Label("삭제된 순간", systemImage: "minus.circle").font(.whisperControl)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.whisperSurfaceFocus)
        .accessibilityIdentifier("ipad.journal.sourceList")
    }

    @discardableResult
    private func persistDraft() -> Bool { didFinish || recordStore.writingDraftStore.save(draft) }

    private func close() {
        guard persistDraft() else { isDraftErrorPresented = true; return }
        didFinish = true
        dismiss()
    }

    private func save() {
        let recoveryDay = isOriginalDeleted ? JournalDay(date: recoveryDate, calendar: draft.day.calendar) : nil
        guard recordStore.saveJournalDraft(draft, recoveringDeletedJournalOn: recoveryDay) != nil else {
            isSaveErrorPresented = true
            return
        }
        didFinish = true
        dismiss()
    }
}
