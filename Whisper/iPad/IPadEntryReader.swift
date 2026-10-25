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
                IPadEmptyState(title: String(localized: "기록을 찾을 수 없어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
            }
        }
        .background(Color.whisperBackground)
        .modifier(IPadReaderTitle(isPresented: presentsNavigationTitle, title: journal != nil ? String(localized: "나의 하루", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : String(localized: "남긴 순간", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)))
        .toolbar {
            if moment != nil || journal != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(String(localized: "수정", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), systemImage: "pencil", action: edit)
                            .accessibilityIdentifier("ipad.reader.editButton")
                        Button(String(localized: "삭제", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), systemImage: "trash", role: .destructive) { isDeleteConfirmationPresented = true }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.whisperTextPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "기록 메뉴", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .accessibilityIdentifier("ipad.reader")
        .sheet(item: $selectedPhoto) { DiaryPhotoViewer(photo: $0) }
        .alert(journal != nil ? String(localized: "이 일기를 삭제할까요?", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : String(localized: "이 순간을 삭제할까요?", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), isPresented: $isDeleteConfirmationPresented) {
            Button(String(localized: "취소", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), role: .cancel) {}
            Button(String(localized: "삭제", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), role: .destructive, action: delete)
        } message: {
            Text(journal != nil
                 ? String(localized: "완성한 일기와 출처 연결이 삭제돼요. 원본 순간과 그 사진은 그대로 남아요. 삭제한 일기는 복구할 수 없어요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
                 : String(localized: "순간 원본과 사진이 삭제돼요. 이미 일기에 담은 글과 사진은 그대로 남아요. 삭제한 순간은 복구할 수 없어요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
        }
        .alert(String(localized: "기록을 삭제할 수 없어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), isPresented: $isDeleteErrorPresented) {
            Button(String(localized: "확인", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), role: .cancel) {}
        } message: { Text(String(localized: "기록은 그대로 남아 있어요. 잠시 후 다시 시도해 주세요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) }
    }

    private func document(_ value: DiaryDocument) -> some View {
        DiaryTextView(document: .constant(value), isFocused: .constant(false), isEditable: false, minimumHeight: 0,
                      showsRules: journal != nil,
                      editorAccessibilityLabel: moment != nil ? String(localized: "순간 본문", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale) : String(localized: "일기 내용", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale),
                      onPhotoTap: { selectedPhoto = $0 })
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
