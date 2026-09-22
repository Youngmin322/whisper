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
    @State private var isDetailRecordPresented = false
    @State private var shouldOpenDetailAfterSheetDismisses = false
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

                if dueCommitment != nil {
                    memorySection
                }

                jarCard

                if dueCommitment == nil {
                    memorySection
                }

                recentSection
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
        .sheet(
            isPresented: $isQuickRecordPresented,
            onDismiss: openDetailAfterSheetDismissesIfNeeded
        ) {
            QuickRecordView(
                draft: $recordDraft,
                onSave: { saveDraft() },
                onOpenDetail: { shouldOpenDetailAfterSheetDismisses = true }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(WhisperRadius.sheet)
        }
        .navigationDestination(isPresented: $isDetailRecordPresented) {
            DetailedRecordView(draft: $recordDraft) { emotion, photoData in
                saveDraft(emotion: emotion, photoData: photoData)
            }
        }
        .onChange(of: isDetailRecordPresented) { _, isPresented in
            guard !isPresented else { return }
            presentPendingCommitmentCandidateIfPossible()
        }
        .alert("알림을 켜야 다시 건넬 수 있어요", isPresented: $isReminderUnavailablePresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("결심은 기억해 두었어요. 설정에서 알림을 허용하면 앱을 열지 않아도 다시 만날 수 있어요.")
        }
    }

    private var jarCard: some View {
        VStack(spacing: WhisperSpacing.medium) {
            if dynamicTypeSize.isAccessibilitySize {
                jarIntroduction
                CollectionFlameJar(storedFlameCount: recordStore.records.count, width: 92)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .center, spacing: WhisperSpacing.small) {
                    jarIntroduction
                    Spacer(minLength: 0)
                    CollectionFlameJar(storedFlameCount: recordStore.records.count, width: 92)
                }
            }

            Button {
                isQuickRecordPresented = true
            } label: {
                Label("마음 담기", systemImage: "plus")
            }
            .buttonStyle(.whisperPrimary)
            .accessibilityIdentifier("home.recordButton")
        }
        .padding(WhisperSpacing.large)
        .frame(maxWidth: .infinity)
        .whisperCardStyle(
            fill: .whisperSurfaceHighlight,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.sheet
        )
    }

    private var jarIntroduction: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
            Text("나의 유리병")
                .font(.whisperControl)
                .foregroundStyle(Color.whisperAccentText)

            Text(recordStore.records.isEmpty ? "첫 마음을 담아볼까요?" : "마음이 이곳에 쌓이고 있어요")
                .font(.whisperNavigationTitle)
                .foregroundStyle(Color.whisperTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(recordStore.records.isEmpty
                 ? "한 문장만 남겨도 괜찮아요."
                 : "\(recordStore.records.count)개의 기록을 간직하고 있어요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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

                    Text(recordStore.commitments.contains(where: { $0.isActive })
                         ? "간직한 문장은 때가 되면 이곳에서 다시 만나요."
                         : "기록 속 결심이 보이면 다시 만날지 먼저 물어볼게요.")
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

    @ViewBuilder
    private var recentSection: some View {
        if !recentRecords.isEmpty {
            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                HStack {
                    Text("최근 담은 마음")
                        .font(.whisperSectionTitle)
                        .foregroundStyle(Color.whisperTextPrimary)
                    Spacer()
                    Button("모두 보기", action: onOpenCollection)
                        .font(.whisperControl)
                        .foregroundStyle(Color.whisperAccentText)
                        .frame(minHeight: WhisperSize.controlCompact)
                }

                ForEach(recentRecords) { record in
                    NavigationLink {
                        RecordDetailView(record: record, recordStore: recordStore)
                    } label: {
                        HStack(alignment: .top, spacing: WhisperSpacing.small) {
                            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                                Text(record.id == recentlySavedRecordID
                                     ? "방금 담은 마음" : record.createdAt.whisperRecordHeaderDescription)
                                    .font(.whisperMetadata)
                                    .foregroundStyle(Color.whisperAccentText)
                                Text(record.content)
                                    .font(.whisperBody)
                                    .foregroundStyle(Color.whisperTextPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.whisperTextSecondary)
                        }
                        .padding(WhisperSpacing.medium)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                        .whisperCardStyle(fill: .whisperSurfaceDefault, border: .whisperBorderSubtle)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(record.createdAt.whisperFullDayDescription) 기록, \(record.content)")
                }
            }
        }
    }

    private var recentRecords: [WhisperRecord] {
        Array(recordStore.records.sorted { $0.createdAt > $1.createdAt }.prefix(2))
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

    private func saveDraft(emotion: String? = nil, photoData: Data? = nil) -> Bool {
        let title = recordDraft.titleForSaving
        let content = recordDraft.contentForSaving
        let existingCommitments = recordStore.activeCommitmentSnapshots

        guard let savedRecord = recordStore.addAndReturn(
            title: title,
            content: content,
            emotion: emotion ?? recordDraft.emotion,
            photoData: photoData
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

    private func openDetailAfterSheetDismissesIfNeeded() {
        if shouldOpenDetailAfterSheetDismisses {
            shouldOpenDetailAfterSheetDismisses = false
            isDetailRecordPresented = true
        } else {
            presentPendingCommitmentCandidateIfPossible()
        }
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
              !isDetailRecordPresented,
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
