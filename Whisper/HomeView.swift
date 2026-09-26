//
//  HomeView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct HomeView: View {
    let recordStore: RecordStore
    let onOpenCollection: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isQuickRecordPresented = false
    @State private var recordDraft = RecordDraft()
    @State private var pendingCommitmentCandidates: [CommitmentCandidate] = []
    @State private var presentedCommitmentCandidate: CommitmentCandidate?
    @State private var recentlySavedRecordID: UUID?
    @State private var isReminderUnavailablePresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WhisperSpacing.xLarge) {
                Text(Date.now.whisperDayDescription)
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)

                if let candidate = presentedCommitmentCandidate {
                    candidateCard(candidate)
                }

                todayPage

                if dueCommitment != nil || !recordStore.commitments.isEmpty {
                    memorySection
                }

                Button("지난 기록 모두 보기", action: onOpenCollection)
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperAccentText)
                    .frame(maxWidth: .infinity, minHeight: WhisperSize.controlCompact)
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, WhisperSpacing.small)
            .padding(.bottom, WhisperSpacing.xxLarge)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color.whisperBackground)
        .navigationTitle("오늘")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isQuickRecordPresented, onDismiss: presentPendingCommitmentCandidateIfPossible) {
            QuickRecordView(
                draft: $recordDraft,
                onSave: { saveDraft() }
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled(recordDraft.hasChanges)
        }
        .alert("알림을 켜야 다시 건넬 수 있어요", isPresented: $isReminderUnavailablePresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("결심은 기억해 두었어요. 설정에서 알림을 허용하면 앱을 열지 않아도 다시 만날 수 있어요.")
        }
    }

    private var todayPage: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.large) {
            if dynamicTypeSize.isAccessibilitySize {
                todayPageIntroduction
                CollectionFlameJar(storedFlameCount: recordStore.records.count, width: 64)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            } else {
                HStack(alignment: .center, spacing: WhisperSpacing.small) {
                    todayPageIntroduction
                    Spacer(minLength: 0)
                    CollectionFlameJar(storedFlameCount: recordStore.records.count, width: 64)
                        .accessibilityHidden(true)
                }
            }

            if todayMoments.isEmpty {
                Text("아직 오늘 남긴 순간이 없어요. 떠오른 장면 하나부터 시작해 보세요.")
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(todayMoments) { record in
                    todayMomentRow(record)
                }
            }

            momentAction

            Divider()

            if let journal = recordStore.journal(on: .now) {
                savedJournal(journal)
            } else if todayMoments.isEmpty {
                directJournalLink
            } else {
                journalAction
            }
        }
        .padding(WhisperSpacing.large)
        .frame(maxWidth: .infinity)
        .whisperCardStyle(
            fill: .whisperSurfaceHighlight,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.sheet
        )
    }

    private var todayPageIntroduction: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
            Text("오늘의 순간 · \(todayMoments.count)개")
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            Text("떠오를 때 남겨 두고, 하루를 정리할 때 골라 쓸 수 있어요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var momentAction: some View {
        if todayMoments.isEmpty {
            Button {
                isQuickRecordPresented = true
            } label: {
                Label("순간 남기기", systemImage: "plus")
            }
            .buttonStyle(.whisperPrimary)
            .accessibilityIdentifier("home.recordButton")
        } else {
            Button {
                isQuickRecordPresented = true
            } label: {
                Label("순간 더 남기기", systemImage: "plus")
            }
            .buttonStyle(.whisperSecondary)
            .accessibilityIdentifier("home.recordButton")
        }
    }

    private func todayMomentRow(_ record: WhisperRecord) -> some View {
        NavigationLink {
            RecordDetailView(record: record, recordStore: recordStore)
        } label: {
            HStack(alignment: .top, spacing: WhisperSpacing.small) {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.whisperAccentText)
                    .padding(.top, 6)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                    Text(record.id == recentlySavedRecordID
                         ? "방금 남긴 순간"
                         : record.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperAccentText)
                    Text(record.content)
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    if record.emotion != nil || record.photoData != nil {
                        HStack(spacing: WhisperSpacing.small) {
                            if let emotion = record.emotion {
                                Text(emotion)
                            }
                            if record.photoData != nil {
                                Label("사진", systemImage: "photo")
                            }
                        }
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.whisperTextSecondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, WhisperSpacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("순간, \(record.createdAt.whisperFullDayDescription), \(record.content), 원본 열기")
        .accessibilityIdentifier("home.momentRow")
    }

    private var directJournalLink: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
            Text("한 번에 하루를 쓰고 싶다면")
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)
            NavigationLink {
                JournalEditorView(date: .now, recordStore: recordStore)
            } label: {
                Label("순간 없이 일기 쓰기", systemImage: "book.pages")
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperAccentText)
                    .frame(maxWidth: .infinity, minHeight: WhisperSize.controlCompact, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.journalButton")
        }
    }

    private var journalAction: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            Text("하루를 정리할 때")
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperAccentText)
            Text("남긴 순간 중 필요한 것을 골라, 내 말로 오늘 일기를 써요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink {
                JournalEditorView(date: .now, recordStore: recordStore)
            } label: {
                Label("오늘 일기 정리하기", systemImage: "book.pages")
            }
            .buttonStyle(.whisperPrimary)
            .accessibilityIdentifier("home.journalButton")
        }
    }

    private func savedJournal(_ journal: DailyJournal) -> some View {
        NavigationLink {
            JournalDetailView(journalID: journal.id, recordStore: recordStore)
        } label: {
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text("저장한 오늘 일기")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperAccentText)
                Text(journal.title.isEmpty ? "오늘의 일기" : journal.title)
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
                Text(journal.body)
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .lineLimit(2)
                if unlinkedMomentCount(in: journal) > 0 {
                    Text("가져오지 않은 순간 \(unlinkedMomentCount(in: journal))개 · 원하면 일기 수정에서 더할 수 있어요.")
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextSecondary)
                }
                Label("일기 다시 열기", systemImage: "arrow.up.right")
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperAccentText)
                    .padding(.top, WhisperSpacing.xSmall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, WhisperSpacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("저장한 오늘 일기, \(journal.title.isEmpty ? "오늘의 일기" : journal.title), 열기")
        .accessibilityIdentifier("home.journalButton")
    }

    private func unlinkedMomentCount(in journal: DailyJournal) -> Int {
        todayMoments.filter { !journal.sourceRecordIDs.contains($0.id) }.count
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

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text("다시 만날 마음")
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            if let commitment = dueCommitment,
               let record = recordStore.record(withID: commitment.sourceRecordID) {
                NavigationLink {
                    RecordDetailView(
                        record: record,
                        recordStore: recordStore,
                        reminderEncounterID: dueEncounter(for: commitment)?.id,
                        reminderCommitmentID: commitment.id
                    )
                } label: {
                    HStack(alignment: .center, spacing: WhisperSpacing.medium) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(Color.whisperAccentText)
                            .frame(width: 42, height: 42)
                            .background(Color.whisperSurfaceHighlight, in: Circle())

                        VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                            Text("그날의 문장이 기다리고 있어요")
                                .font(.whisperBodyEmphasis)
                                .foregroundStyle(Color.whisperTextPrimary)
                            Text(commitment.quote)
                                .font(.whisperBody)
                                .foregroundStyle(Color.whisperTextSecondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.whisperTextSecondary)
                    }
                    .padding(WhisperSpacing.medium)
                    .whisperCardStyle(fill: .whisperSurfaceDefault, border: .whisperBorderSubtle)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("다시 만날 문장, \(commitment.quote)")
            } else {
                HStack(spacing: WhisperSpacing.medium) {
                    Image(systemName: "envelope.open")
                        .font(.title3)
                        .foregroundStyle(Color.whisperAccentText)
                        .frame(width: 42, height: 42)
                        .background(Color.whisperSurfaceHighlight, in: Circle())

                    Text("간직한 결심과 알림 상태는 설정에서 확인하고 조절할 수 있어요.")
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(WhisperSpacing.medium)
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                .whisperCardStyle(fill: .whisperSurfaceDefault, border: .whisperBorderSubtle)
            }
        }
    }

    private var dueCommitment: WhisperCommitment? {
        recordStore.commitments.first {
            $0.lifecycleStatus() == .active
                && dueEncounter(for: $0) != nil
        }
    }

    private func dueEncounter(for commitment: WhisperCommitment) -> ReminderEncounter? {
        recordStore.encounters.first {
            $0.commitmentID == commitment.id
                && $0.scheduledAt <= .now
                && $0.reaction == nil
        }
    }

    private func saveDraft() -> Bool {
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

        recentlySavedRecordID = savedRecord.id
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
    }

    private func dismissCandidate() {
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
