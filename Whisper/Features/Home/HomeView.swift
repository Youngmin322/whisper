//
//  HomeView.swift
//  Whisper
//

import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    let recordStore: RecordStore
    let onOpenCollection: () -> Void

    @State private var isQuickRecordPresented = false
    @State private var recordDraft = RecordDraft()
    @State private var pendingCommitmentCandidates: [CommitmentCandidate] = []
    @State private var presentedCommitmentCandidate: CommitmentCandidate?
    @State private var isReminderUnavailablePresented = false
    @State private var isCandidatePresented = false
    @State private var today = JournalDay(date: .now)
    @State private var dayRefreshID = UUID()
    @State private var isDraftListPresented = false
    @State private var pendingMomentDraft: RecordDraft?
    @State private var pendingJournalDraft: JournalWritingDraft?
    @State private var resumedJournalDraft: JournalWritingDraft?
    @State private var isResumedJournalPresented = false
    @State private var resumedMomentDraft: RecordDraft?
    @State private var isResumedMomentPresented = false

    var body: some View {
        FlameHomeScreen(
            day: today,
            records: todayMoments,
            recordStore: recordStore,
            isRecording: isQuickRecordPresented || isCandidatePresented,
            onAddMoment: openMoment,
            onOpenCollection: onOpenCollection
        )
        .safeAreaInset(edge: .top) {
            if recordStore.writingDraftStore.count > 0 || recordStore.writingDraftStore.errorMessage != nil {
                Button { isDraftListPresented = true } label: {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text(String(localized: "작성 중인 기록 이어 쓰기 · \(recordStore.writingDraftStore.count)", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .padding(WhisperSpacing.medium)
                    .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
                }
                .accessibilityIdentifier("home.resumeDraftsButton")
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.vertical, WhisperSpacing.xSmall)
                .background(Color.whisperBackground)
            }
        }
        .task(id: dayRefreshID) {
            while !Task.isCancelled {
                refreshDay(reschedule: false)
                let delay = max(0.01, today.nextBoundary.timeIntervalSinceNow)
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshDay() }
        .sheet(isPresented: $isQuickRecordPresented, onDismiss: presentPendingCommitmentCandidateIfPossible) {
            QuickRecordView(
                draft: $recordDraft,
                draftStore: recordStore.writingDraftStore,
                onSave: { saveDraft() }
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled(recordStore.writingDraftStore.errorMessage != nil)
        }
        .sheet(isPresented: $isDraftListPresented, onDismiss: openSelectedDraft) {
            WritingDraftListView(draftStore: recordStore.writingDraftStore, onOpenMoment: { draft in
                pendingMomentDraft = draft
                isDraftListPresented = false
            }, onOpenJournal: { draft in
                pendingJournalDraft = draft
                isDraftListPresented = false
            })
        }
        .navigationDestination(isPresented: $isResumedJournalPresented) {
            if let resumedJournalDraft { JournalEditorView(draft: resumedJournalDraft, recordStore: recordStore) }
        }
        .navigationDestination(isPresented: $isResumedMomentPresented) {
            if let resumedMomentDraft, let id = resumedMomentDraft.existingRecordID,
               let record = recordStore.record(withID: id) {
                RecordDetailView(record: record, recordStore: recordStore, editingDraft: resumedMomentDraft)
            }
        }
        .sheet(isPresented: $isCandidatePresented, onDismiss: dismissCandidate) {
            if let candidate = presentedCommitmentCandidate {
                candidateCard(candidate)
                    .padding(24)
                    .presentationDetents([.medium])
            }
        }
        .alert(String(localized: "알림을 켜야 다시 건넬 수 있어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), isPresented: $isReminderUnavailablePresented) {
            Button(String(localized: "확인", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), role: .cancel) {}
        } message: {
            Text(String(localized: "결심은 기억해 두었어요. 설정에서 알림을 허용하면 앱을 열지 않아도 다시 만날 수 있어요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
        }
    }

    private var todayMoments: [WhisperRecord] {
        recordStore.uncollectedMoments(on: today)
    }

    private func openMoment() {
        recordDraft = RecordDraft()
        isQuickRecordPresented = true
    }

    private func openSelectedDraft() {
        if let journal = pendingJournalDraft {
            pendingJournalDraft = nil
            resumedJournalDraft = journal
            isResumedJournalPresented = true
        } else if let moment = pendingMomentDraft {
            pendingMomentDraft = nil
            if let id = moment.existingRecordID, recordStore.record(withID: id) != nil {
                resumedMomentDraft = moment
                isResumedMomentPresented = true
            } else {
                recordDraft = moment
                isQuickRecordPresented = true
            }
        }
    }

    private func refreshDay(reschedule: Bool = true) {
        let current = JournalDay(date: .now)
        if today != current { today = current }
        if reschedule { dayRefreshID = UUID() }
    }

    private func candidateCard(_ candidate: CommitmentCandidate) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            Label(String(localized: "기록에서 이런 결심을 찾았어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), systemImage: "sparkle")
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            Text("“\(candidate.quote)”")
                .font(.whisperBodyLarge)
                .foregroundStyle(Color.whisperTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(localized: "이 문장을 나중에 다시 건넬까요? 기록은 어느 쪽이든 보관돼요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)

            Button(String(localized: "다시 만나기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) {
                remember(candidate, firstReminderDate: nil)
                dismissCandidate()
            }
            .buttonStyle(.whisperPrimary(size: .compact))
            .accessibilityIdentifier("commitment.rememberButton")

            Button(String(localized: "기록만 보관하기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), action: dismissCandidate)
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

        guard let savedRecord = recordStore.saveMomentDraft(recordDraft, recoveringDeletedMoment: recordDraft.existingRecordID != nil) else {
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
        guard CommitmentReminderFeature.isEnabled else { return }

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
