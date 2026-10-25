import SwiftUI

struct WritingDraftErrorView: View {
    let message: String?
    let onRetry: () -> Void

    var body: some View {
        if let message {
            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                Text(message)
                    .font(.whisperBody)
                Button(String(localized: "임시 저장 다시 시도"), action: onRetry)
                    .font(.whisperControl)
                    .accessibilityIdentifier("draft.retryButton")
            }
            .foregroundStyle(Color.whisperTextPrimary)
            .padding(WhisperSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
        }
    }
}

struct WritingDraftListView: View {
    @Environment(\.dismiss) private var dismiss
    let draftStore: WritingDraftStore
    let onOpenMoment: (RecordDraft) -> Void
    let onOpenJournal: (JournalWritingDraft) -> Void
    @State private var draftToDiscard: UUID?
    @State private var isDiscardConfirmationPresented = false

    var body: some View {
        NavigationStack {
            List {
                if let error = draftStore.errorMessage {
                    WritingDraftErrorView(message: error, onRetry: draftStore.retry)
                }
                if draftStore.momentDrafts.contains(where: \.hasChanges) {
                    Section(String(localized: "순간")) {
                        ForEach(draftStore.momentDrafts.filter(\.hasChanges)) { moment in
                            Button { onOpenMoment(moment) } label: {
                                draftLabel(title: moment.title.isEmpty ? String(localized: "작성 중인 순간") : moment.title,
                                           subtitle: moment.content.isEmpty ? (moment.emotion ?? String(localized: "이어서 작성하기")) : moment.content)
                            }
                            .accessibilityIdentifier("draft.resumeMomentButton")
                            .swipeActions { discardButton(id: moment.id) }
                        }
                    }
                }
                if !draftStore.momentEditDrafts.isEmpty {
                    Section(String(localized: "수정 중인 순간")) {
                        ForEach(draftStore.momentEditDrafts) { moment in
                            Button { onOpenMoment(moment) } label: {
                                draftLabel(title: moment.title.isEmpty ? String(localized: "수정 중인 순간") : moment.title,
                                           subtitle: moment.content)
                            }
                            .accessibilityIdentifier("draft.resumeMomentEditButton")
                            .swipeActions { discardButton(id: moment.id) }
                        }
                    }
                }
                if !draftStore.journalDrafts.isEmpty {
                    Section(String(localized: "일기")) {
                        ForEach(draftStore.journalDrafts) { journal in
                            Button { onOpenJournal(journal) } label: {
                                draftLabel(title: journal.day.fullDescription,
                                           subtitle: journal.title.isEmpty ? journal.body : journal.title)
                            }
                            .accessibilityIdentifier("draft.resumeJournalButton")
                            .swipeActions { discardButton(id: journal.id) }
                        }
                    }
                }
                if !draftStore.unreadableDrafts.isEmpty {
                    Section(String(localized: "읽을 수 없는 초안")) {
                        Text(String(localized: "이 초안의 원본과 사진은 기기에 그대로 보관하고 있어요. 다른 초안은 계속 작성할 수 있어요."))
                            .font(.whisperBody)
                            .foregroundStyle(Color.whisperTextSecondary)
                        ForEach(draftStore.unreadableDrafts) { draft in
                            Label {
                                Text(draft.updatedAt.whisperDateTimeDescription)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle")
                            }
                            .accessibilityIdentifier("draft.unreadable.\(draft.id)")
                        }
                        Button(String(localized: "초안 다시 불러오기"), action: draftStore.retry)
                            .accessibilityIdentifier("draft.reloadUnreadableButton")
                        Text(String(localized: "다시 불러와도 열리지 않으면 원본을 복구할 때까지 이 앱과 데이터를 삭제하지 말아 주세요."))
                            .font(.whisperCaption)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }
                }
                if draftStore.count == 0 {
                    Text(String(localized: "작성 중인 초안이 없어요."))
                        .foregroundStyle(Color.whisperTextSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.whisperBackground)
            .navigationTitle(String(localized: "작성 중인 기록"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "닫기")) { dismiss() } }
            }
            .confirmationDialog(String(localized: "이 초안을 버릴까요?"), isPresented: $isDiscardConfirmationPresented, titleVisibility: .visible) {
                Button(String(localized: "초안 버리기"), role: .destructive) {
                    if let id = draftToDiscard { draftStore.discard(id: id) }
                    draftToDiscard = nil
                }
                Button(String(localized: "계속 보관"), role: .cancel) { draftToDiscard = nil }
            } message: {
                Text(String(localized: "이미 저장한 기록은 그대로 남아요."))
            }
        }
    }

    private func draftLabel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text(title).font(.whisperControl).foregroundStyle(Color.whisperTextPrimary)
            Text(subtitle.isEmpty ? String(localized: "이어서 작성하기") : subtitle)
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, WhisperSpacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func discardButton(id: UUID) -> some View {
        Button(String(localized: "초안 버리기"), role: .destructive) {
            draftToDiscard = id
            isDiscardConfirmationPresented = true
        }
    }
}
