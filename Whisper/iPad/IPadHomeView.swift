import SwiftUI
import UIKit

struct IPadHomeView: View {
    let recordStore: RecordStore
    let onAddMoment: () -> Void
    let onCollect: (JournalDay) -> Void
    let onResumeDrafts: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var today = JournalDay(date: .now)
    @State private var selectedRecordID: UUID?
    @State private var isInspectorPresented = false
    @State private var collectionStartedAt: Date?
    @State private var collectionTask: Task<Void, Never>?

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
                    selectedRecordID = $0
                    isInspectorPresented = true
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
        .inspector(isPresented: $isInspectorPresented) {
            NavigationStack {
                if let selectedRecordID, let record = recordStore.record(withID: selectedRecordID) {
                    RecordDetailView(record: record, recordStore: recordStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button { isInspectorPresented = false } label: { Image(systemName: "xmark") }
                                    .accessibilityLabel("선택한 순간 닫기")
                            }
                        }
                }
            }
            .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .task(id: today) {
            do {
                try await Task.sleep(for: .seconds(max(0.01, today.nextBoundary.timeIntervalSinceNow)))
                refreshDay()
            } catch {}
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshDay() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshDay() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in refreshDay() }
        .onChange(of: recordStore.records.map(\.id)) { _, ids in
            if let selectedRecordID, !ids.contains(selectedRecordID) { isInspectorPresented = false }
        }
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
            isInspectorPresented = false
            today = day
        }
    }

    private func collect() {
        guard !moments.isEmpty, collectionStartedAt == nil else { return }
        let day = today
        isInspectorPresented = false
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
}
