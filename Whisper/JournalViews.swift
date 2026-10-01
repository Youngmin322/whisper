import SwiftUI
import WhisperDesignSystem

struct JournalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let recordStore: RecordStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: JournalWritingDraft
    @State private var isSaveErrorPresented = false
    @State private var isDiscardConfirmationPresented = false
    @State private var isDraftErrorPresented = false
    @State private var didFinish = false

    init(date: Date, recordStore: RecordStore) {
        self.init(day: JournalDay(date: date), recordStore: recordStore)
    }

    init(journal: DailyJournal, recordStore: RecordStore) {
        self.init(day: JournalDay(date: journal.displayDate), recordStore: recordStore, existing: journal)
    }

    init(day: JournalDay, recordStore: RecordStore, existing: DailyJournal? = nil) {
        self.recordStore = recordStore
        let journal = existing ?? recordStore.journal(on: day)
        let restored = recordStore.writingDraftStore.journalDraft(on: day, existingJournalID: journal?.id)
        let value = restored ?? JournalWritingDraft(day: day, existing: journal, records: recordStore.records)
        _draft = State(initialValue: value.includingNewMoments(from: recordStore.records))
    }

    init(draft: JournalWritingDraft, recordStore: RecordStore) {
        self.recordStore = recordStore
        _draft = State(initialValue: draft.includingNewMoments(from: recordStore.records))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(draft.day.fullDescription)
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperTextSecondary)

                if !moments.isEmpty {
                    HStack(spacing: 4) {
                        Spacer()
                        ForEach(moments.suffix(5)) { record in
                            FlameCharacter(emotion: record.emotion, size: 32)
                        }
                    }
                    .accessibilityHidden(true)
                }

                WritingDraftErrorView(message: recordStore.writingDraftStore.errorMessage) { persistDraft() }
                writingSection
            }
            .padding(.horizontal, 30)
            .padding(.top, 18)
            .padding(.bottom, 110)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.whisperBackground)
        .navigationTitle("나의 하루")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("닫기", action: close).accessibilityIdentifier("journal.closeButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("초안 버리기", role: .destructive) { isDiscardConfirmationPresented = true }
                    .accessibilityIdentifier("journal.discardDraftButton")
            }
        }
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { persistDraft() }
        }
        .onDisappear { persistDraft() }
        .confirmationDialog("작성 중인 일기 초안을 버릴까요?", isPresented: $isDiscardConfirmationPresented, titleVisibility: .visible) {
            Button("초안 버리기", role: .destructive) {
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
        .safeAreaInset(edge: .bottom) {
            Button("일기 저장", action: save)
                .buttonStyle(.whisperPrimary)
                .disabled(draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("journal.saveButton")
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.vertical, WhisperSpacing.small)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .background(Color.whisperBackground)
        }
        .alert("일기를 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("작성한 내용은 이 화면에 남아 있어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private var writingSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextEditor(text: $draft.body)
                .font(.custom("NotoSansKR-Thin", size: 17, relativeTo: .body))
                .foregroundStyle(Color.whisperTextPrimary)
                .lineSpacing(18)
                .scrollContentBackground(.hidden)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 480 : 410)
                .background(alignment: .topLeading) {
                    Canvas { context, size in
                        var lines = Path()
                        for y in stride(from: CGFloat(44), through: size.height, by: 47) {
                            lines.move(to: CGPoint(x: 0, y: y))
                            lines.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(lines, with: .color(Color.whisperBorderSubtle.opacity(0.7)), lineWidth: 1)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if draft.body.isEmpty {
                        Text("오늘을 돌아보며 적어보세요.")
                            .font(.whisperBodyLarge)
                            .foregroundStyle(Color.whisperTextSecondary)
                            .padding(.leading, 5)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel("일기 본문")
                .accessibilityIdentifier("journal.bodyField")

            Text("오늘을 돌아보며 더 적어보세요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary.opacity(0.7))

            Text("남긴 순간은 원문 그대로 담았어요")
                .font(.whisperHandwriting(19))
                .foregroundStyle(Color.whisperTextSecondary)

            Text("제목 · 선택 사항")
                .font(.whisperControl)
            TextField("이 하루를 알아볼 짧은 이름", text: $draft.title)
                .font(.whisperBodyLarge)
                .padding(WhisperSpacing.medium)
                .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: WhisperRadius.medium)
                        .stroke(Color.whisperBorderSubtle, lineWidth: 1)
                }
                .accessibilityIdentifier("journal.titleField")

            if draft.existingJournalID != nil || !moments.isEmpty {
                Menu {
                    ForEach(WhisperEmotion.selectableCases) { emotion in
                        Button(emotion.rawValue) { draft.representativeEmotion = emotion.rawValue }
                    }
                } label: {
                    Text("대표 감정 · \(draft.representativeEmotion ?? "선택 안 함")")
                        .font(.whisperControl)
                        .foregroundStyle(Color.whisperTextSecondary)
                }
            }
        }
    }

    private var moments: [WhisperRecord] {
        recordStore.records.filter { draft.day.contains($0.createdAt) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        didFinish || recordStore.writingDraftStore.save(draft)
    }

    private func close() {
        guard persistDraft() else { isDraftErrorPresented = true; return }
        didFinish = true
        dismiss()
    }

    private func save() {
        guard recordStore.saveJournalDraft(draft) != nil else {
            isSaveErrorPresented = true
            return
        }
        didFinish = true
        dismiss()
    }
}

struct JournalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let journalID: UUID
    let recordStore: RecordStore
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleteErrorPresented = false

    var body: some View {
        Group {
            if let journal {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(journal.displayDate.whisperFullDayDescription)
                            .font(.whisperControl)
                            .foregroundStyle(Color.whisperTextSecondary)

                        HStack {
                            if !journal.title.isEmpty {
                                Text(journal.title)
                                    .font(.whisperHandwriting(26, bold: true))
                            }
                            Spacer()
                            FlameCharacter(emotion: journal.emotion, size: 38)
                        }

                        Text(journal.body)
                            .font(.whisperBodyLarge)
                            .lineSpacing(20)
                            .foregroundStyle(Color.whisperTextPrimary)
                            .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
                            .background(alignment: .topLeading) {
                                Canvas { context, size in
                                    var lines = Path()
                                    for y in stride(from: CGFloat(45), through: size.height, by: 47) {
                                        lines.move(to: CGPoint(x: 0, y: y))
                                        lines.addLine(to: CGPoint(x: size.width, y: y))
                                    }
                                    context.stroke(lines, with: .color(Color.whisperBorderSubtle.opacity(0.7)), lineWidth: 1)
                                }
                            }
                            .textSelection(.enabled)

                        if !journal.reflection.isEmpty {
                            Text(journal.reflection)
                                .font(.whisperBody)
                                .textSelection(.enabled)
                        }

                        Text("남긴 순간은 원문 그대로 담았어요")
                            .font(.whisperHandwriting(19))
                            .foregroundStyle(Color.whisperTextSecondary)

                        DisclosureGroup("담긴 순간 · \(availableSourceCount(in: journal))/\(journal.sourceRecordIDs.count)개 열람 가능") {
                            ForEach(journal.sourceRecordIDs, id: \.self) { id in
                                sourceRow(id)
                                    .padding(.vertical, 6)
                            }
                        }
                        .font(.whisperControl)
                        .foregroundStyle(Color.whisperTextSecondary)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 18)
                    .padding(.bottom, 50)
                }
            } else {
                ContentUnavailableView("일기를 찾을 수 없어요", systemImage: "book.closed")
            }
        }
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

    @ViewBuilder
    private func sourceRow(_ id: UUID) -> some View {
        if let record = recordStore.record(withID: id) {
            NavigationLink {
                RecordDetailView(record: record, recordStore: recordStore)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                    Text("순간 · \(record.createdAt.whisperDateTimeDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if record.photoData != nil {
                        Label("사진 있음", systemImage: "photo")
                            .font(.caption)
                    }
                }
            }
            .accessibilityLabel("출처 순간, \(record.title), 원본 상세 열기")
        } else {
            Label("삭제된 순간 · 원본과 사진을 볼 수 없어요", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func availableSourceCount(in journal: DailyJournal) -> Int {
        journal.sourceRecordIDs.filter { recordStore.record(withID: $0) != nil }.count
    }

    private func delete() {
        guard let journal, recordStore.deleteJournal(journal) else {
            isDeleteErrorPresented = true
            return
        }
        dismiss()
    }
}
