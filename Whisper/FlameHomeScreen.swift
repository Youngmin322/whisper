import SwiftUI

struct FlameHomeScreen: View {
    let records: [WhisperRecord]
    let recordStore: RecordStore
    let onAddMoment: () -> Void
    let onOpenCollection: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedRecordID: UUID?
    @State private var isRecordPresented = false
    @State private var isJournalPresented = false
    @State private var isSettingsPresented = false
    @State private var collectionStartedAt: Date?

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

            HStack(spacing: 10) {
                Button("+ 순간 남기기", action: onAddMoment)
                    .foregroundStyle(Color.whisperAccentText)
                    .accessibilityIdentifier("home.recordButton")
                Button("병에 담기", action: collect)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .disabled(records.isEmpty || collectionStartedAt != nil)
                    .accessibilityIdentifier("home.journalButton")
            }
            .font(.whisperControl)
            .buttonStyle(HomePillButtonStyle())
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

private struct HomePillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 114, minHeight: 44)
            .padding(.horizontal, 5)
            .background(Color.whisperSurfaceDefault.opacity(0.96), in: Capsule())
            .overlay(Capsule().stroke(Color.whisperBorderSubtle, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
