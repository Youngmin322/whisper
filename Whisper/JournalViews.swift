import SwiftUI
import WhisperDesignSystem

struct JournalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let recordStore: RecordStore
    @State private var draft: JournalWritingDraft
    @State private var isSaveErrorPresented = false
    @State private var isDiscardConfirmationPresented = false
    @State private var isDraftErrorPresented = false
    @State private var didFinish = false
    @State private var isBodyFocused = false
    @State private var selectedPhoto: DiaryPhoto?
    @State private var recoveryDate: Date

    init(date: Date, recordStore: RecordStore) {
        self.init(day: JournalDay(date: date), recordStore: recordStore)
    }

    init(journal: DailyJournal, recordStore: RecordStore) {
        self.init(day: JournalDay(date: journal.displayDate), recordStore: recordStore, existing: journal)
    }

    init(day: JournalDay, recordStore: RecordStore, existing: DailyJournal? = nil) {
        self.recordStore = recordStore
        _recoveryDate = State(initialValue: day.date)
        let journal = existing ?? recordStore.journal(on: day)
        let restored = recordStore.writingDraftStore.journalDraft(on: day, existingJournalID: journal?.id)
        let moments = recordStore.uncollectedMoments(on: day)
        let value = restored ?? JournalWritingDraft(day: day, existing: journal, records: journal == nil ? moments : [])
        let prepared = recordStore.prepareJournalDraft(value, existing: journal)
        _draft = State(initialValue: prepared.includingNewMoments(from: moments,
            documents: Dictionary(uniqueKeysWithValues: moments.map { ($0.id, recordStore.diaryDocument(for: $0)) })))
    }

    init(draft: JournalWritingDraft, recordStore: RecordStore) {
        self.recordStore = recordStore
        _recoveryDate = State(initialValue: draft.day.date)
        let journal = recordStore.journals.first { $0.id == draft.existingJournalID }
        let moments = recordStore.uncollectedMoments(on: draft.day)
        let prepared = recordStore.prepareJournalDraft(draft, existing: journal)
        _draft = State(initialValue: prepared.includingNewMoments(from: moments,
            documents: Dictionary(uniqueKeysWithValues: moments.map { ($0.id, recordStore.diaryDocument(for: $0)) })))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text(draft.day.fullDescription)
                            .font(.whisperMetadata)
                            .foregroundStyle(Color.whisperTextSecondary)
                        Spacer(minLength: 12)
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
                        .font(.whisperHandwriting(28, bold: true))
                        .foregroundStyle(Color.whisperTextPrimary)
                        .accessibilityIdentifier("journal.titleField")
                    Rectangle().fill(Color.whisperDivider).frame(height: 1)
                }
                WritingDraftErrorView(message: recordStore.writingDraftStore.errorMessage) { persistDraft() }
                if isOriginalDeleted {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("원본 일기가 삭제되었어요")
                            .font(.whisperAction)
                        Text("작성한 초안은 남아 있어요. 날짜를 선택해 새 일기로 저장할 수 있어요.")
                            .font(.whisperBody)
                        DatePicker("복구할 날짜", selection: $recoveryDate, displayedComponents: .date)
                            .environment(\.calendar, draft.day.calendar)
                            .environment(\.timeZone, draft.day.calendar.timeZone)
                            .accessibilityIdentifier("journal.recoveryDatePicker")
                    }
                    .foregroundStyle(Color.whisperTextPrimary)
                }
                DiaryTextView(document: Binding(
                    get: { draft.document ?? DiaryDocument(text: draft.body) },
                    set: { draft.document = $0; draft.body = $0.text }
                ), isFocused: $isBodyFocused, minimumHeight: 260, showsRules: true,
                   accessibilityIdentifier: "journal.bodyField",
                   onPhotoTap: { selectedPhoto = $0 })
                    .overlay(alignment: .topLeading) {
                        if draft.body.isEmpty, draft.document?.photos.isEmpty != false {
                            Text("오늘을 돌아보며 적어보세요.")
                                .font(.whisperBodyLarge)
                                .foregroundStyle(Color.whisperTextSecondary)
                                .allowsHitTesting(false)
                        }
                    }
                DiarySourcesView(ids: draft.sourceRecordIDs, recordStore: recordStore)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 30)
            .padding(.top, 18)
            .padding(.bottom, 50)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.whisperBackground)
        .navigationTitle("나의 하루")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { isDiscardConfirmationPresented = true } label: {
                    Image(systemName: "trash").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.whisperTextSecondary)
                .accessibilityLabel("초안 삭제")
                .accessibilityHint("작성 중인 초안만 삭제해요.")
                .accessibilityIdentifier("journal.discardDraftButton")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isOriginalDeleted ? "새 일기로 저장" : "저장", action: save)
                    .font(.whisperAction)
                    .tint(Color.whisperAccentText)
                    .disabled(draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(isOriginalDeleted ? "새 일기로 저장" : "일기 저장")
                    .accessibilityIdentifier("journal.saveButton")
            }

        }
        .sheet(item: $selectedPhoto) { DiaryPhotoViewer(photo: $0) }
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { persistDraft() } }
        .onDisappear { persistDraft() }
        .confirmationDialog("작성 중인 일기 초안을 삭제할까요?", isPresented: $isDiscardConfirmationPresented, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                guard recordStore.writingDraftStore.discard(id: draft.id) else {
                    isDraftErrorPresented = true
                    return
                }
                didFinish = true
                dismiss()
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("이미 저장한 일기와 원본 순간은 그대로 남아요.")
        }
        .alert("초안을 보관할 수 없어요", isPresented: $isDraftErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("작성한 내용은 이 화면에 남아 있어요. 임시 저장을 다시 시도해 주세요.")
        }
        .alert("일기를 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(recordStore.journalDraftSaveFailure?.message ?? JournalDraftSaveFailure.storageFailure.message)
        }
    }

    @discardableResult
    private func persistDraft() -> Bool { didFinish || recordStore.writingDraftStore.save(draft) }

    private var isOriginalDeleted: Bool {
        draft.existingJournalID.map { originalID in
            !recordStore.journals.contains { $0.id == originalID }
        } ?? false
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

struct DiaryPageHeader: View {
    let date: String
    let title: String
    let emotion: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(date).font(.whisperMetadata).foregroundStyle(Color.whisperTextSecondary)
                Spacer(minLength: 12)
                FlameCharacter(emotion: emotion, size: 38)
                    .accessibilityLabel(emotion ?? "남긴 마음")
            }
            if !title.isEmpty {
                Text(title).font(.whisperHandwriting(28, bold: true)).foregroundStyle(Color.whisperTextPrimary)
            }
            Rectangle().fill(Color.whisperDivider).frame(height: 1)
        }
    }
}

struct DiarySourcesView: View {
    let ids: [UUID]
    let recordStore: RecordStore
    var body: some View {
        if !ids.isEmpty {
            DisclosureGroup("담아 둔 순간 · \(ids.count)개") {
                ForEach(ids, id: \.self) { id in sourceRow(id).padding(.vertical, 6) }
            }
            .font(.whisperControl)
            .foregroundStyle(Color.whisperTextSecondary)
        }
    }

    @ViewBuilder
    private func sourceRow(_ id: UUID) -> some View {
        if let record = recordStore.record(withID: id) {
            NavigationLink {
                RecordDetailView(record: record, recordStore: recordStore)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                    Text(record.createdAt.whisperDateTimeDescription)
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperTextSecondary)
                    if record.photoData != nil { Label("사진 있음", systemImage: "photo").font(.whisperCaption) }
                }
            }
            .accessibilityLabel("출처 순간, \(record.title), 원본 상세 열기")
        } else {
            Label("삭제된 순간 · 원본을 볼 수 없어요", systemImage: "minus.circle")
        }
    }
}

struct JournalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let journalID: UUID
    let recordStore: RecordStore
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleteErrorPresented = false
    @State private var selectedPhoto: DiaryPhoto?

    var body: some View {
        Group {
            if let journal {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        DiaryPageHeader(date: journal.displayDate.whisperFullDayDescription,
                                        title: journal.title, emotion: journal.emotion)
                        DiaryTextView(document: .constant(recordStore.diaryDocument(for: journal)),
                                      isFocused: .constant(false), isEditable: false,
                                      minimumHeight: 0, showsRules: true,
                                      onPhotoTap: { selectedPhoto = $0 })
                        DiarySourcesView(ids: journal.sourceRecordIDs, recordStore: recordStore)
                            .padding(.top, 18)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 18)
                    .padding(.bottom, 50)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
            } else {
                ContentUnavailableView("일기를 찾을 수 없어요", systemImage: "book.closed")
            }
        }
        .sheet(item: $selectedPhoto) { DiaryPhotoViewer(photo: $0) }
        .background(Color.whisperBackground)
        .navigationTitle("나의 하루")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let journal {
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink("수정") {
                        JournalEditorView(journal: journal, recordStore: recordStore)
                    }
                    .accessibilityLabel("일기 수정")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("일기 삭제", systemImage: "trash", role: .destructive) {
                            isDeleteConfirmationPresented = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("일기 메뉴")
                }
            }
        }
        .alert("이 일기를 삭제할까요?", isPresented: $isDeleteConfirmationPresented) {
            Button("취소", role: .cancel) {}
            Button("일기 삭제", role: .destructive, action: delete)
        } message: {
            Text("완성한 일기의 본문, 감정, 회고와 출처 연결이 삭제돼요. 순간 원본과 그 사진은 그대로 남아요. 삭제한 일기는 복구할 수 없어요.")
        }
        .alert("일기를 삭제할 수 없어요", isPresented: $isDeleteErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("일기는 그대로 남아 있어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private var journal: DailyJournal? {
        recordStore.journals.first { $0.id == journalID }
    }

    private func delete() {
        guard let journal, recordStore.deleteJournal(journal) else {
            isDeleteErrorPresented = true
            return
        }
        dismiss()
    }
}
