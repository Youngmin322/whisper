//
//  HomeView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct HomeView: View {
    let recordStore: RecordStore
    let onOpenCollection: () -> Void

    @State private var isQuickRecordPresented = false
    @State private var recordDraft = RecordDraft()
    @State private var pendingCommitmentCandidates: [CommitmentCandidate] = []
    @State private var presentedCommitmentCandidate: CommitmentCandidate?
    @State private var isReminderUnavailablePresented = false
    @State private var isCandidatePresented = false

    var body: some View {
        FlameHomeScreen(
            records: todayMoments,
            recordStore: recordStore,
            isRecording: isQuickRecordPresented || isCandidatePresented,
            onAddMoment: { isQuickRecordPresented = true },
            onOpenCollection: onOpenCollection
        )
        .sheet(isPresented: $isQuickRecordPresented, onDismiss: presentPendingCommitmentCandidateIfPossible) {
            QuickRecordView(
                draft: $recordDraft,
                onSave: { saveDraft() }
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled(recordDraft.hasChanges)
        }
        .sheet(isPresented: $isCandidatePresented, onDismiss: dismissCandidate) {
            if let candidate = presentedCommitmentCandidate {
                candidateCard(candidate)
                    .padding(24)
                    .presentationDetents([.medium])
            }
        }
        .alert("알림을 켜야 다시 건넬 수 있어요", isPresented: $isReminderUnavailablePresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("결심은 기억해 두었어요. 설정에서 알림을 허용하면 앱을 열지 않아도 다시 만날 수 있어요.")
        }
    }

    private var todayMoments: [WhisperRecord] {
        recordStore.records
            .filter { Calendar.current.isDateInToday($0.createdAt) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func candidateCard(_ candidate: CommitmentCandidate) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            Label("기록에서 이런 결심을 찾았어요", systemImage: "sparkle")
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            Text("“\(candidate.quote)”")
                .font(.whisperBodyLarge)
                .foregroundStyle(Color.whisperTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("이 문장을 나중에 다시 건넬까요? 기록은 어느 쪽이든 보관돼요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)

            Button("다시 만나기") {
                remember(candidate, firstReminderDate: nil)
                dismissCandidate()
            }
            .buttonStyle(.whisperPrimary(size: .compact))
            .accessibilityIdentifier("commitment.rememberButton")

            Button("기록만 보관하기", action: dismissCandidate)
                .font(.whisperControl)
                .foregroundStyle(Color.whisperTextSecondary)
                .frame(maxWidth: .infinity, minHeight: WhisperSize.controlCompact)
        }
        .padding(WhisperSpacing.large)
        .whisperCardStyle(fill: .whisperSurfaceDefault, border: .whisperBorderSubtle)
        .accessibilityIdentifier("commitment.candidateCard")
    }

    private func saveDraft() -> Bool {
        guard recordDraft.canSaveNewMoment else { return false }
        let title = recordDraft.titleForSaving
        let content = recordDraft.contentForSaving
        let existingCommitments = recordStore.activeCommitmentSnapshots

        guard let savedRecord = recordStore.addAndReturn(
            title: title,
            content: content,
            emotion: recordDraft.emotion,
            photoData: recordDraft.photoData
        ) else {
            return false
        }

        recordDraft = RecordDraft()
        analyzeSavedRecord(
            savedRecord,
            title: title,
            content: content,
            existingCommitments: existingCommitments
        )
        return true
    }

    private func analyzeSavedRecord(
        _ record: WhisperRecord,
        title: String,
        content: String,
        existingCommitments: [CommitmentSnapshot]
    ) {
        Task {
            let analysis = await CommitmentAnalyzer().analyze(
                recordID: record.id,
                title: title,
                content: content,
                activeCommitments: existingCommitments
            )

            guard recordStore.record(withID: record.id) != nil else { return }

            if let continuedCommitmentID = analysis.continuedCommitmentID,
               let plan = recordStore.continueCommitment(
                continuedCommitmentID,
                reminderProfile: analysis.continuedReminderProfile
               ) {
                let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
                if result != .scheduled {
                    isReminderUnavailablePresented = true
                }
            }

            if let candidate = analysis.candidate {
                pendingCommitmentCandidates.append(candidate)
            }
            presentPendingCommitmentCandidateIfPossible()
        }
    }

    private func presentPendingCommitmentCandidateIfPossible() {
        guard !isQuickRecordPresented,
              presentedCommitmentCandidate == nil,
              !pendingCommitmentCandidates.isEmpty
        else {
            return
        }

        presentedCommitmentCandidate = pendingCommitmentCandidates.removeFirst()
        isCandidatePresented = true
    }

    private func dismissCandidate() {
        isCandidatePresented = false
        presentedCommitmentCandidate = nil
        presentPendingCommitmentCandidateIfPossible()
    }

    private func remember(_ candidate: CommitmentCandidate, firstReminderDate: Date?) {
        guard let plan = recordStore.rememberCommitment(
            sourceRecordID: candidate.sourceRecordID,
            name: candidate.name,
            quote: candidate.quote,
            topics: candidate.topics,
            reminderProfile: candidate.reminderProfile,
            firstReminderDate: firstReminderDate
        ) else {
            return
        }

        Task {
            let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
            if result != .scheduled {
                isReminderUnavailablePresented = true
            }
        }
    }
}

private struct HomePreview: View {
    private let recordStore: RecordStore

    init() {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let oldDate = Calendar.current.date(byAdding: .day, value: -84, to: .now) ?? .now
        store.add(
            title: "그때의 작은 결심",
            content: "조급해하지 말고 오늘 할 수 있는 한 가지에 집중하자.",
            createdAt: oldDate
        )
        if let record = store.latestRecord {
            _ = store.rememberCommitment(
                sourceRecordID: record.id,
                name: "오늘 할 수 있는 한 가지",
                quote: record.content,
                topics: ["집중", "작은 시작"],
                reminderTiming: .fallback,
                now: oldDate
            )
        }
        recordStore = store
    }

    var body: some View {
        NavigationStack {
            HomeView(recordStore: recordStore, onOpenCollection: {})
        }
    }
}

#Preview { HomePreview() }
