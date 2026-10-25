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
                                   placeholder: String(localized: "오늘을 돌아보며 적어보세요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), accessibilityIdentifier: "journal.bodyField",
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
            .navigationTitle(String(localized: "나의 하루", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) { Image(systemName: "xmark") }
                        .accessibilityLabel(String(localized: "일기 작성 닫기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                        .accessibilityHint(String(localized: "작성 중인 초안을 보관해요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                        .accessibilityIdentifier("journal.closeButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { isDiscardConfirmationPresented = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel(String(localized: "초안 삭제", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                        .accessibilityIdentifier("journal.discardDraftButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isOriginalDeleted ? String(localized: "새 일기로 저장", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : String(localized: "저장", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.whisperAccent)
                        .disabled(draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut("s", modifiers: .command)
                        .accessibilityIdentifier("journal.saveButton")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button { isBodyFocused = false } label: { Image(systemName: "keyboard.chevron.compact.down") }
                        .accessibilityLabel(String(localized: "키보드 내리기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                }
            }
        }
        .tint(Color.whisperTextSecondary)
        .sheet(item: $selectedPhoto) { DiaryPhotoViewer(photo: $0) }
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { persistDraft() } }
        .onDisappear { persistDraft() }
        .confirmationDialog(String(localized: "작성 중인 일기 초안을 삭제할까요?", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), isPresented: $isDiscardConfirmationPresented, titleVisibility: .visible) {
            Button(String(localized: "초안 삭제", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), role: .destructive) {
                guard recordStore.writingDraftStore.discard(id: draft.id) else { isDraftErrorPresented = true; return }
                didFinish = true
                dismiss()
            }
            Button(String(localized: "계속 작성", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), role: .cancel) {}
        } message: { Text(String(localized: "이미 저장한 일기와 원본 순간은 그대로 남아요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) }
        .alert(String(localized: "초안을 보관할 수 없어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), isPresented: $isDraftErrorPresented) {
            Button(String(localized: "확인", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), role: .cancel) {}
        } message: { Text(String(localized: "작성한 내용은 이 화면에 남아 있어요. 임시 저장을 다시 시도해 주세요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) }
        .alert(String(localized: "일기를 저장할 수 없어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), isPresented: $isSaveErrorPresented) {
            Button(String(localized: "확인", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), role: .cancel) {}
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
                        Button(emotion.displayName) { draft.representativeEmotion = emotion.rawValue }
                    }
                } label: {
                    FlameCharacter(emotion: draft.representativeEmotion, size: 38)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(String(localized: "대표 감정 바꾸기, 현재 \(WhisperEmotion.displayName(for: draft.representativeEmotion) ?? String(localized: "선택 안 함", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
            }
            TextField(String(localized: "이 하루의 제목 · 선택 사항", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), text: $draft.title, axis: .vertical)
                .font(.whisperHandwriting(28))
                .accessibilityIdentifier("journal.titleField")
            Divider()
        }
        .foregroundStyle(Color.whisperTextPrimary)
    }

    private var recoveryNotice: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text(String(localized: "원본 일기가 삭제되었어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)).font(.whisperAction)
            Text(String(localized: "날짜를 선택해 이 초안을 새 일기로 저장할 수 있어요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)).font(.whisperBody)
            DatePicker(String(localized: "복구할 날짜", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), selection: $recoveryDate, displayedComponents: .date)
                .environment(\.calendar, draft.day.calendar)
                .environment(\.timeZone, draft.day.calendar.timeZone)
                .accessibilityIdentifier("journal.recoveryDatePicker")
        }
    }

    private var sourceColumn: some View {
        List {
            Section(String(localized: "담아 둔 순간 · \(draft.sourceRecordIDs.count)개", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) {
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
                        Text(String(localized: "삭제된 순간", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)).font(.whisperControl)
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
