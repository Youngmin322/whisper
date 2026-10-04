import SwiftUI

struct FlameHomeScreen: View {
    let day: JournalDay
    let records: [WhisperRecord]
    let recordStore: RecordStore
    let isRecording: Bool
    let onAddMoment: () -> Void
    let onOpenCollection: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("lastJournalCollectionProposalDay") private var lastProposalDay = ""
    @State private var selectedRecordID: UUID?
    @State private var isRecordPresented = false
    @State private var isJournalPresented = false
    @State private var isSettingsPresented = false
    @State private var collectionStartedAt: Date?
    @State private var collectionDay: JournalDay?
    @State private var collectionTask: Task<Void, Never>?
    @State private var isTimeProposalPresented = false

    var body: some View {
        VStack(spacing: 0) {
            HomeToolbarView(day: day, onOpenSettings: { isSettingsPresented = true },
                            onOpenCollection: onOpenCollection)
                .disabled(collectionStartedAt != nil)

            if records.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text(recordStore.journal(on: day) == nil
                         ? "아직 오늘의 불꽃이 없어요"
                         : "오늘의 불꽃을 병에 담았어요")
                        .font(.whisperHandwriting(24))
                        .foregroundStyle(Color.whisperTextPrimary)
                    Text(recordStore.journal(on: day) == nil
                         ? "떠오른 순간 하나를 남겨보세요"
                         : "새로운 순간이 떠오르면 또 남겨보세요")
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                TodayFlameField(
                    records: records,
                    collectionStartedAt: collectionStartedAt,
                    onSelect: openRecord,
                    isPaused: isRecording
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.whisperBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarSpacer(.flexible, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                HomeActionButton(title: "병에 담기", image: Image("BottleLineIcon"), action: collect)
                    .disabled(records.isEmpty || collectionStartedAt != nil)
                    .accessibilityIdentifier("home.journalButton")
                    .accessibilityHint("오늘 남긴 순간을 모아 일기를 작성해요.")
            }

            ToolbarSpacer(.fixed, placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                HomeActionButton(title: "순간 남기기", image: Image(systemName: "plus"), action: onAddMoment)
                    .accessibilityIdentifier("home.recordButton")
                    .disabled(collectionStartedAt != nil)
            }
        }
        .navigationDestination(isPresented: $isRecordPresented) {
            if let selectedRecordID,
               let record = recordStore.record(withID: selectedRecordID) {
                RecordDetailView(record: record, recordStore: recordStore)
            }
        }
        .navigationDestination(isPresented: $isJournalPresented) {
            if let collectionDay {
                JournalEditorView(day: collectionDay, recordStore: recordStore)
            }
        }
        .navigationDestination(isPresented: $isSettingsPresented) {
            SettingsView(recordStore: recordStore)
        }
        .sheet(isPresented: $isTimeProposalPresented) {
            timeProposal
                .presentationDetents([.height(378)])
                .presentationDragIndicator(.visible)
        }
        .task {
            while !Task.isCancelled {
                proposeCollectionIfNeeded()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onChange(of: records.count) { _, _ in proposeCollectionIfNeeded() }
        .onChange(of: isJournalPresented) { _, presented in
            if !presented {
                collectionStartedAt = nil
                collectionDay = nil
            }
        }
        .onChange(of: isRecording) { _, recording in
            if !recording { proposeCollectionIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { proposeCollectionIfNeeded() }
        }
        .onChange(of: day) { _, _ in proposeCollectionIfNeeded() }
        .onDisappear {
            if !isJournalPresented {
                collectionTask?.cancel()
                collectionStartedAt = nil
                collectionDay = nil
            }
        }
    }

    private var timeProposal: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("오후 10:00 · 오늘을 돌아볼 시간")
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperAccentText)
                .padding(.top, 44)
            Text("오늘의 순간을\n일기로 모아볼까요?")
                .font(.custom("NotoSansKR-Thin", size: 22, relativeTo: .title2))
                .foregroundStyle(Color.whisperTextPrimary)
                .lineSpacing(5)
                .padding(.top, 18)
            Text("나중에 해도 기록은 그대로 남아요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .padding(.top, 24)
            Spacer()
            Button("병에 담고 일기 쓰기") {
                isTimeProposalPresented = false
                collect()
            }
            .buttonStyle(.whisperPrimary)
            Button("나중에") { isTimeProposalPresented = false }
                .font(.whisperControl)
                .foregroundStyle(Color.whisperAccentText)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .padding(.horizontal, 30)
        .background(Color.whisperBackground.ignoresSafeArea())
    }

    private func proposeCollectionIfNeeded() {
        guard !isRecording,
              collectionStartedAt == nil,
              Calendar.current.component(.hour, from: .now) >= 22,
              !records.isEmpty,
              recordStore.journal(on: day) == nil
        else { return }
        let today = day.key
        guard lastProposalDay != today else { return }
        lastProposalDay = today
        isTimeProposalPresented = true
    }

    private func openRecord(_ id: UUID) {
        guard collectionStartedAt == nil else { return }
        selectedRecordID = id
        isRecordPresented = true
    }

    private func collect() {
        guard !records.isEmpty, collectionStartedAt == nil else { return }
        collectionDay = day
        collectionStartedAt = .now
        collectionTask = Task { @MainActor in
            do {
                if !reduceMotion { try await Task.sleep(for: .milliseconds(820)) }
            } catch { return }
            guard !Task.isCancelled else { return }
            isJournalPresented = true
        }
    }
}

private struct HomeActionButton: View {
    let title: String
    let image: Image
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            image
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 24)
                .foregroundStyle(Color.whisperTextOnAccent)
                .accessibilityHidden(true)
        }
        .font(.system(size: 20, weight: .medium))
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .controlSize(.regular)
        .tint(Color.whisperButtonBackground)
        .accessibilityLabel(title)
    }
}
