import SwiftUI

struct FlameHomeScreen: View {
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
    @State private var isTimeProposalPresented = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    Button("보관함", systemImage: "archivebox", action: onOpenCollection)
                    Button("설정", systemImage: "gearshape") { isSettingsPresented = true }
                } label: {
                    Image("HanddrawnMenu")
                        .resizable()
                        .frame(width: 30, height: 27)
                        .frame(width: 48, height: 48, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("메뉴")
                .accessibilityIdentifier("home.menuButton")
                Spacer()
            }
            .padding(.horizontal, 21)
            .padding(.top, 8)

            Text(Date.now.formatted(Date.FormatStyle().locale(Locale(identifier: "ko_KR")).month(.wide).day()))
                .font(.whisperHandwriting(27, bold: true))
                .foregroundStyle(Color.whisperTextPrimary)
                .padding(.horizontal, 6)
                .background(alignment: .bottom) {
                    Capsule()
                        .fill(Color.whisperSurfaceHighlight)
                        .frame(height: 7)
                        .offset(y: 2)
                }
                .padding(.top, 12)

            if records.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("아직 오늘의 불꽃이 없어요")
                        .font(.whisperHandwriting(24))
                        .foregroundStyle(Color.whisperTextPrimary)
                    Text("떠오른 순간 하나를 남겨보세요")
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                TodayFlameField(
                    records: records,
                    collectionStartedAt: collectionStartedAt,
                    onSelect: openRecord
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(spacing: 4) {
                Button("+ 순간 남기기", action: onAddMoment)
                    .buttonStyle(HomeMomentButtonStyle())
                    .accessibilityIdentifier("home.recordButton")

                Button(action: collect) {
                    HStack(spacing: 4) {
                        Image("BottleLineIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 19, height: 23)
                            .accessibilityHidden(true)
                        Text("병에 담기")
                    }
                }
                .buttonStyle(HomeCollectButtonStyle())
                .disabled(records.isEmpty || collectionStartedAt != nil)
                .accessibilityIdentifier("home.journalButton")
            }
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.whisperBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isRecordPresented) {
            if let selectedRecordID,
               let record = recordStore.record(withID: selectedRecordID) {
                RecordDetailView(record: record, recordStore: recordStore)
            }
        }
        .navigationDestination(isPresented: $isJournalPresented) {
            JournalEditorView(date: .now, recordStore: recordStore)
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
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .onChange(of: records.count) { _, _ in proposeCollectionIfNeeded() }
        .onChange(of: isRecording) { _, recording in
            if !recording { proposeCollectionIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { proposeCollectionIfNeeded() }
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
            .font(.whisperAction)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.whisperAccent, in: RoundedRectangle(cornerRadius: 18))
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
              Calendar.current.component(.hour, from: .now) >= 22,
              !records.isEmpty,
              recordStore.journal(on: .now) == nil
        else { return }
        let today = JournalDayKey.make(for: .now)
        guard lastProposalDay != today else { return }
        lastProposalDay = today
        isTimeProposalPresented = true
    }

    private func openRecord(_ id: UUID) {
        selectedRecordID = id
        isRecordPresented = true
    }

    private func collect() {
        guard !records.isEmpty, collectionStartedAt == nil else { return }
        collectionStartedAt = .now
        Task { @MainActor in
            if !reduceMotion {
                try? await Task.sleep(for: .milliseconds(820))
            }
            isJournalPresented = true
            collectionStartedAt = nil
        }
    }
}

private struct HomeMomentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.whisperControl)
            .foregroundStyle(Color.whisperTextOnAccent)
            .frame(width: 151, height: 44)
            .background(Color.whisperAccent, in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct HomeCollectButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.whisperControl)
            .foregroundStyle(Color.whisperTextSecondary)
            .frame(minWidth: 116, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(!isEnabled ? 0.45 : configuration.isPressed ? 0.6 : 1)
    }
}
