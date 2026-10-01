import SwiftUI
import WhisperDesignSystem

struct WritingDraftErrorView: View {
    let message: String?
    let onRetry: () -> Void

    var body: some View {
        if let message {
            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                Text(message)
                    .font(.whisperBody)
                Button("임시 저장 다시 시도", action: onRetry)
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
                if let moment = draftStore.momentDraft, moment.hasChanges {
                    Section("순간") {
                        Button { onOpenMoment(moment) } label: {
                            draftLabel(title: moment.title.isEmpty ? "작성 중인 순간" : moment.title,
                                       subtitle: moment.content.isEmpty ? (moment.emotion ?? "이어서 작성하기") : moment.content)
                        }
                        .accessibilityIdentifier("draft.resumeMomentButton")
                        .swipeActions { discardButton(id: moment.id) }
                    }
                }
                if !draftStore.journalDrafts.isEmpty {
                    Section("일기") {
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
                if draftStore.count == 0 {
                    Text("작성 중인 초안이 없어요.")
                        .foregroundStyle(Color.whisperTextSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.whisperBackground)
            .navigationTitle("작성 중인 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .confirmationDialog("이 초안을 버릴까요?", isPresented: $isDiscardConfirmationPresented, titleVisibility: .visible) {
                Button("초안 버리기", role: .destructive) {
                    if let id = draftToDiscard { draftStore.discard(id: id) }
                    draftToDiscard = nil
                }
                Button("계속 보관", role: .cancel) { draftToDiscard = nil }
            } message: {
                Text("이미 저장한 기록은 그대로 남아요.")
            }
        }
    }

    private func draftLabel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text(title).font(.whisperControl).foregroundStyle(Color.whisperTextPrimary)
            Text(subtitle.isEmpty ? "이어서 작성하기" : subtitle)
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, WhisperSpacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func discardButton(id: UUID) -> some View {
        Button("초안 버리기", role: .destructive) {
            draftToDiscard = id
            isDiscardConfirmationPresented = true
        }
    }
}
