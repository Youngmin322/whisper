import SwiftUI
import UIKit

struct IPadHomeView: View {
    let recordStore: RecordStore
    let onAddMoment: () -> Void
    let onCollect: (JournalDay) -> Void
    let onResumeDrafts: () -> Void
    let onSelectMoment: (UUID) -> Void
    let onCloseSelection: () -> Void
    var isInspecting = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("lastJournalCollectionProposalDay") private var lastProposalDay = ""
    @State private var today = JournalDay(date: .now)
    @State private var collectionStartedAt: Date?
    @State private var collectionTask: Task<Void, Never>?
    @State private var isTimeProposalPresented = false

    private var moments: [WhisperRecord] { recordStore.uncollectedMoments(on: today) }

    var body: some View {
        homeContent
        .navigationTitle(String(localized: "오늘의 불꽃"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { dateLabel }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) { collectButton }
            ToolbarSpacer(.fixed, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) { recordButton }
        }
        .background(Color.whisperBackground)
        .task(id: today) {
            while !Task.isCancelled {
                proposeCollectionIfNeeded()
                do {
                    try await Task.sleep(for: .seconds(min(60, max(0.01, today.nextBoundary.timeIntervalSinceNow))))
                } catch { return }
                refreshDay()
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshDay() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshDay() }
        .onChange(of: recordStore.records.map(\.id)) { _, _ in proposeCollectionIfNeeded() }
        .alert(String(localized: "오늘의 순간을 일기로 모아볼까요?"), isPresented: $isTimeProposalPresented) {
            Button(String(localized: "병에 담고 일기 쓰기"), action: collect)
            Button(String(localized: "나중에"), role: .cancel) {}
        } message: { Text(String(localized: "오늘을 돌아볼 시간이에요. 나중에 해도 기록은 그대로 남아요.")) }
        .onDisappear {
            collectionTask?.cancel()
            collectionStartedAt = nil
        }
    }

    private var homeContent: some View {
        VStack(spacing: 0) {
            if recordStore.writingDraftStore.count > 0 || recordStore.writingDraftStore.errorMessage != nil {
                Button(action: onResumeDrafts) {
                    Text(String(localized: "작성 중인 기록 이어 쓰기"))
                        .font(.whisperControl)
                }
                .accessibilityIdentifier("ipad.home.resumeDraftsButton")
                .padding(.horizontal, WhisperSpacing.xxLarge)
                .padding(.bottom, WhisperSpacing.small)
            }

            if moments.isEmpty {
                IPadEmptyState(title: recordStore.journal(on: today) == nil
                               ? String(localized: "아직 오늘의 불꽃이 없어요") : String(localized: "오늘의 불꽃을 병에 담았어요"),
                               message: recordStore.journal(on: today) == nil
                               ? String(localized: "떠오른 순간 하나를 남겨보세요") : String(localized: "새로운 순간이 떠오르면 또 남겨보세요"))
            } else {
                TodayFlameField(records: moments, collectionStartedAt: collectionStartedAt, onSelect: {
                    onSelectMoment($0)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var dateLabel: some View {
        Text(today.shortDescription)
            .font(.whisperHandwriting(27))
            .foregroundStyle(Color.whisperTextPrimary)
            .padding(.horizontal, 6)
            .background(alignment: .bottom) {
                Capsule().fill(Color.whisperSurfaceHighlight).frame(height: 7).offset(y: 2)
            }
            .accessibilityLabel(String(localized: "\(today.fullDescription), 오늘 남긴 순간 \(moments.count)개"))
            .accessibilityIdentifier("home.dateLabel")
    }

    private var collectButton: some View {
        Button(action: collect) {
            Image("Jar")
                .renderingMode(.original)
                .resizable().scaledToFit()
                .frame(width: 20, height: 24)
        }
        .buttonBorderShape(.circle)
        .tint(Color.whisperAccent)
        .disabled(moments.isEmpty || collectionStartedAt != nil)
        .accessibilityLabel(String(localized: "병에 담기"))
        .accessibilityHint(String(localized: "오늘 남긴 순간을 모아 일기를 작성해요."))
        .accessibilityIdentifier("home.journalButton")
    }

    private var recordButton: some View {
        Button(action: onAddMoment) { Image(systemName: "plus").font(.system(size: 20, weight: .medium)) }
            .buttonBorderShape(.circle)
            .tint(Color.whisperAccent)
            .keyboardShortcut("n", modifiers: .command)
            .disabled(collectionStartedAt != nil)
            .accessibilityLabel(String(localized: "순간 남기기"))
            .accessibilityIdentifier("home.recordButton")
    }

    private func refreshDay() {
        let day = JournalDay(date: .now)
        if day != today {
            collectionTask?.cancel()
            collectionStartedAt = nil
            onCloseSelection()
            today = day
        }
    }

    private func collect() {
        guard !moments.isEmpty, collectionStartedAt == nil else { return }
        let day = today
        let duration = FlameCollectionMotion(count: moments.count).duration
        onCloseSelection()
        collectionStartedAt = .now
        collectionTask = Task { @MainActor in
            do {
                if !reduceMotion { try await Task.sleep(for: .seconds(duration)) }
            } catch { return }
            guard !Task.isCancelled else { return }
            collectionStartedAt = nil
            onCollect(day)
        }
    }

    private func proposeCollectionIfNeeded() {
        guard scenePhase == .active, collectionStartedAt == nil,
              !isInspecting, Calendar.current.component(.hour, from: .now) >= 22,
              !moments.isEmpty, recordStore.journal(on: today) == nil,
              lastProposalDay != today.key else { return }
        lastProposalDay = today.key
        isTimeProposalPresented = true
    }
}
