import SwiftUI

enum IPadEntry: Hashable, Identifiable {
    case moment(UUID), journal(UUID)

    var id: String {
        switch self {
        case .moment(let id): "moment:\(id)"
        case .journal(let id): "journal:\(id)"
        }
    }
}

struct IPadEntryReader: View {
    let entry: IPadEntry
    let recordStore: RecordStore
    let onEdit: (IPadEditorSession) -> Void
    var onDelete: () -> Void = {}
    var presentsNavigationTitle = true
    var searchContext: JournalSearchContext? = nil

    @State private var selectedPhoto: DiaryPhoto?
    @State private var isDeleteConfirmationPresented = false
    @State private var isDeleteErrorPresented = false

    private var moment: WhisperRecord? {
        if case .moment(let id) = entry { recordStore.record(withID: id) } else { nil }
    }
    private var journal: DailyJournal? {
        if case .journal(let id) = entry { recordStore.journals.first { $0.id == id } } else { nil }
    }

    var body: some View {
        Group {
            if moment != nil || journal != nil {
                ScrollView {
                    IPadPaper {
                        VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                            if let moment {
                                DiaryPageHeader(date: moment.createdAt.whisperRecordHeaderDescription,
                                                title: moment.title, emotion: moment.emotion)
                                document(recordStore.diaryDocument(for: moment))
                            } else if let journal {
                                DiaryPageHeader(date: journal.displayDate.whisperFullDayDescription,
                                                title: journal.title, emotion: journal.emotion)
                                document(recordStore.diaryDocument(for: journal))
                                DiarySourcesView(ids: journal.sourceRecordIDs, recordStore: recordStore,
                                                 searchContext: searchContext)
                            }
                        }
                    }
                    .padding(WhisperSpacing.large)
                    .frame(maxWidth: .infinity)
                }
            } else {
                IPadEmptyState(title: "기록을 찾을 수 없어요")
            }
        }
        .background(Color.whisperBackground)
        .modifier(IPadReaderTitle(isPresented: presentsNavigationTitle, title: journal != nil ? "나의 하루" : "남긴 순간"))
        .toolbar {
            if moment != nil || journal != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("수정", systemImage: "pencil", action: edit)
                            .accessibilityIdentifier("ipad.reader.editButton")
                        Button("삭제", systemImage: "trash", role: .destructive) { isDeleteConfirmationPresented = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.whisperTextPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("기록 메뉴")
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .accessibilityIdentifier("ipad.reader")
        .sheet(item: $selectedPhoto) { DiaryPhotoViewer(photo: $0) }
        .alert(journal != nil ? "이 일기를 삭제할까요?" : "이 순간을 삭제할까요?", isPresented: $isDeleteConfirmationPresented) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive, action: delete)
        } message: {
            Text(journal != nil
                 ? "완성한 일기와 출처 연결이 삭제돼요. 원본 순간과 그 사진은 그대로 남아요. 삭제한 일기는 복구할 수 없어요."
                 : "순간 원본과 사진이 삭제돼요. 이미 일기에 담은 글과 사진은 그대로 남아요. 삭제한 순간은 복구할 수 없어요.")
        }
        .alert("기록을 삭제할 수 없어요", isPresented: $isDeleteErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: { Text("기록은 그대로 남아 있어요. 잠시 후 다시 시도해 주세요.") }
    }

    private func document(_ value: DiaryDocument) -> some View {
        DiaryTextView(document: .constant(value), isFocused: .constant(false), isEditable: false, minimumHeight: 0,
                      showsRules: journal != nil, onPhotoTap: { selectedPhoto = $0 })
    }

    private func edit() {
        if let moment {
            onEdit(.moment(IPadDraftPreparation.moment(moment, store: recordStore)))
        } else if let journal {
            let day = JournalDay(date: journal.displayDate)
            let draft = recordStore.writingDraftStore.journalDraft(on: day, existingJournalID: journal.id)
                ?? JournalWritingDraft(day: day, existing: journal, records: [])
            onEdit(.journal(draft))
        }
    }

    private func delete() {
        let didDelete: Bool
        if let moment { didDelete = recordStore.delete(moment) }
        else if let journal { didDelete = recordStore.deleteJournal(journal) }
        else { return }
        if didDelete { onDelete() } else { isDeleteErrorPresented = true }
    }
}

private struct IPadReaderTitle: ViewModifier {
    let isPresented: Bool
    let title: String

    @ViewBuilder func body(content: Content) -> some View {
        if isPresented { content.navigationTitle(title).navigationBarTitleDisplayMode(.inline) }
        else { content }
    }
}
