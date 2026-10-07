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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                Text(today.date.whisperDayDescription)
                    .font(.whisperHandwriting(34))
                    .foregroundStyle(Color.whisperTextPrimary)
                Text("오늘 남긴 순간 \(moments.count)개")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
            .padding(WhisperSpacing.xxLarge)

            if recordStore.writingDraftStore.count > 0 || recordStore.writingDraftStore.errorMessage != nil {
                Button(action: onResumeDrafts) {
                    Label("작성 중인 기록 이어 쓰기", systemImage: "square.and.pencil")
                        .font(.whisperControl)
                }
                .accessibilityIdentifier("ipad.home.resumeDraftsButton")
                .padding(.horizontal, WhisperSpacing.xxLarge)
                .padding(.bottom, WhisperSpacing.small)
            }

            if moments.isEmpty {
                ContentUnavailableView {
                    Label(recordStore.journal(on: today) == nil ? "아직 오늘의 불꽃이 없어요" : "오늘의 불꽃을 병에 담았어요", systemImage: "flame")
                        .font(.whisperHandwriting(28))
                } description: {
                    Text("떠오른 순간 하나를 남겨보세요.")
                } actions: {
                    Button("순간 남기기", action: onAddMoment)
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TodayFlameField(records: moments, collectionStartedAt: collectionStartedAt, onSelect: {
                    onSelectMoment($0)
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("불꽃 하나에, 순간 하나")
                    .font(.whisperHandwriting(24))
                    .foregroundStyle(Color.whisperTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, WhisperSpacing.xxLarge)
            }
        }
        .background(Color.whisperBackground)
        .navigationTitle("오늘의 불꽃")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: collect) {
                    Label("병에 담기", systemImage: "tray.and.arrow.down")
                }
                .disabled(moments.isEmpty || collectionStartedAt != nil)
                .accessibilityIdentifier("home.journalButton")
                Button(action: onAddMoment) { Label("순간 남기기", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(collectionStartedAt != nil)
                    .accessibilityIdentifier("home.recordButton")
            }
        }
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
        .alert("오늘의 순간을 일기로 모아볼까요?", isPresented: $isTimeProposalPresented) {
            Button("병에 담고 일기 쓰기", action: collect)
            Button("나중에", role: .cancel) {}
        } message: { Text("오늘을 돌아볼 시간이에요. 나중에 해도 기록은 그대로 남아요.") }
        .onDisappear {
            collectionTask?.cancel()
            collectionStartedAt = nil
        }
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
        onCloseSelection()
        collectionStartedAt = .now
        collectionTask = Task { @MainActor in
            do {
                if !reduceMotion { try await Task.sleep(for: .milliseconds(820)) }
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
