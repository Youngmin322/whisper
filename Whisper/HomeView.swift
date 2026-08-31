//
//  HomeView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct HomeView: View {
    let recordStore: RecordStore
    @State private var isQuickRecordPresented = false
    @State private var isDetailRecordPresented = false
    @State private var shouldOpenDetailAfterSheetDismisses = false
    @State private var recordDraft = RecordDraft()
    @State private var pendingCommitmentCandidates: [CommitmentCandidate] = []
    @State private var presentedCommitmentCandidate: CommitmentCandidate?
    @State private var isReminderUnavailablePresented = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.top, 10)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    todayCard
                    rhythmCard
                    memoryCard
                }
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.whisperBackground)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: $isQuickRecordPresented,
            onDismiss: openDetailAfterSheetDismissesIfNeeded
        ) {
            QuickRecordView(
                draft: $recordDraft,
                onSave: { saveDraft() },
                onOpenDetail: {
                    shouldOpenDetailAfterSheetDismisses = true
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $isDetailRecordPresented) {
            DetailedRecordView(draft: $recordDraft) { emotion, photoData in
                saveDraft(
                    emotion: emotion,
                    photoData: photoData
                )
            }
        }
        .sheet(
            item: $presentedCommitmentCandidate,
            onDismiss: presentPendingCommitmentCandidateIfPossible
        ) { candidate in
            CommitmentCandidateSheet(
                candidate: candidate,
                onRemember: {
                    remember(candidate, firstReminderDate: nil)
                    presentedCommitmentCandidate = nil
                },
                onDismiss: {
                    presentedCommitmentCandidate = nil
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
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
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now.whisperDayDescription)
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)
            Text("오늘의 기록")
                .font(.whisperScreenTitle)
                .foregroundStyle(Color.whisperTextPrimary)
        }
    }
    
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘 떠오른 마음")
                        .font(.whisperControl)
                        .foregroundStyle(Color.whisperAccentText)
                    
                    Text("지금 가장 마음에 남는 것은 무엇인가요?")
                        .font(.whisperBodyEmphasis)
                        .foregroundStyle(Color.whisperTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                WhisperJarAnimation(size: .home)
            }
            
            Button {
                isQuickRecordPresented = true
            } label: {
                Text("기록하기")
            }
            .buttonStyle(.whisperPrimary(size: .compact))
            .padding(.top, hasTodayRecord ? 14 : 24)
            .accessibilityIdentifier("home.recordButton")
        }
        .padding(20)
        .whisperCardStyle(
            fill: .whisperSurfaceHighlight,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.card,
            hasShadow: true
        )
    }
    
    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("이번 주 기록 리듬").font(.whisperSectionTitle)
                Spacer()
                Text("\(recordStore.recordCount(inWeekOf: .now, calendar: calendar)) / 7")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                    rhythmDay(date: date, title: weekdayTitles[index])
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .whisperCardStyle(fill: .whisperSurfaceDefault, border: .whisperBorderSubtle, cornerRadius: WhisperRadius.large)
    }

    @ViewBuilder
    private func rhythmDay(date: Date, title: String) -> some View {
        if recordStore.hasRecord(on: date, calendar: calendar) {
            NavigationLink {
                DayRecordsView(date: date, recordStore: recordStore)
            } label: {
                rhythmDayLabel(date: date, title: title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(date.whisperFullDayDescription) 기록 보기")
        } else if calendar.isDateInToday(date) {
            Button {
                isQuickRecordPresented = true
            } label: {
                rhythmDayLabel(date: date, title: title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("오늘 기록하기")
        } else {
            rhythmDayLabel(date: date, title: title)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(date.whisperFullDayDescription), 기록 없음")
        }
    }

    private func rhythmDayLabel(date: Date, title: String) -> some View {
        let isToday = calendar.isDateInToday(date)
        let hasRecord = recordStore.hasRecord(on: date, calendar: calendar)

        return VStack(spacing: 7) {
            Text(title)
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)

            ZStack {
                Circle()
                    .fill(isToday ? Color.whisperAccent : Color.whisperSurfaceSubtle)
                    .frame(width: 28, height: 28)

                if hasRecord {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isToday ? Color.white : Color.whisperAccent)
                } else if isToday {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var memoryCard: some View {
        if let commitment = dueCommitment,
           let record = recordStore.record(withID: commitment.sourceRecordID) {
            NavigationLink {
                RecordDetailView(
                    record: record,
                    recordStore: recordStore,
                    reminderEncounterID: dueEncounter(for: commitment)?.id
                )
            } label: {
                resurfacingCard(for: commitment)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("다시 만난 불꽃, \(commitment.name)")
        } else {
            waitingMemoryCard
        }
    }

    private func resurfacingCard(for commitment: WhisperCommitment) -> some View {
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("다시 만난 불꽃")
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperAccentText)
                
                Text(commitment.name)
                    .font(.whisperBodyEmphasis)
                    .foregroundStyle(Color.whisperTextPrimary)

                Text("“\(commitment.quote)”")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .lineLimit(2)

                Text("그 마음은 지금도 남아 있나요?")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .padding(.top, 4)
            }
            
            Spacer(minLength: 4)
            
            WhisperJar(size: .small)
        }
        .padding(18)
        .whisperCardStyle(fill: .whisperSurfaceSubtle, border: .whisperBorderSubtle, cornerRadius: WhisperRadius.large)
        .contentShape(Rectangle())
    }

    private var waitingMemoryCard: some View {
        let activeCommitmentCount = recordStore.commitments.filter(\.isActive).count

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Whisper가 기억하는 불꽃")
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperAccentText)

                Text(
                    activeCommitmentCount == 0
                        ? "아직 기억 중인 결심이 없어요"
                        : "\(activeCommitmentCount)개의 마음을 간직하고 있어요"
                )
                    .font(.whisperBodyEmphasis)
                    .foregroundStyle(Color.whisperTextPrimary)

                Text(
                    activeCommitmentCount == 0
                        ? "기록 속 결심이 보이면 기억할지 물어볼게요."
                        : "잊고 지낼 즈음, 조용히 다시 건넬게요."
                )
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
            }

            Spacer(minLength: 4)

            WhisperJar(size: .small)
        }
        .padding(18)
        .whisperCardStyle(
            fill: .whisperSurfaceSubtle,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.large
        )
    }

    private var dueCommitment: WhisperCommitment? {
        recordStore.commitments.first {
            $0.lifecycleStatus() == .active
                && ($0.nextReminderAt ?? .distantFuture) <= .now
        }
    }

    private func dueEncounter(for commitment: WhisperCommitment) -> ReminderEncounter? {
        recordStore.encounters(for: commitment.id).first {
            $0.openedAt == nil && $0.scheduledAt <= .now
        }
    }
    
    private var hasTodayRecord: Bool {
        recordStore.hasRecord(on: .now, calendar: calendar)
    }

    private func saveDraft(
        emotion: String? = nil,
        photoData: Data? = nil
    ) -> Bool {
        let title = recordDraft.titleForSaving
        let content = recordDraft.contentForSaving
        let existingCommitments = recordStore.activeCommitmentSnapshots

        guard let savedRecord = recordStore.addAndReturn(
            title: title,
            content: content,
            emotion: emotion,
            photoData: photoData
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

            // 분석 중 사용자가 원본 기록을 삭제했다면 뒤늦은 결과를 적용하지 않아요.
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
              let candidate = pendingCommitmentCandidates.first
        else {
            return
        }

        pendingCommitmentCandidates.removeFirst()
        presentedCommitmentCandidate = candidate
    }

    private func remember(
        _ candidate: CommitmentCandidate,
        firstReminderDate: Date?
    ) {
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
    
    private var calendar: Calendar {
        Calendar(identifier: .iso8601)
    }

    private var weekdayTitles: [String] {
        ["월", "화", "수", "목", "금", "토", "일"]
    }

    private var weekDates: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else {
            return []
        }

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: week.start)
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
            HomeView(recordStore: recordStore)
        }
    }
}

#Preview { HomePreview() }
