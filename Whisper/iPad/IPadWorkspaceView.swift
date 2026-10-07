import SwiftUI

enum IPadSection: String, CaseIterable, Identifiable {
    case today, archive, search, settings

    var id: Self { self }
    var title: String {
        switch self {
        case .today: "오늘의 불꽃"
        case .archive: "보관함"
        case .search: "기억 찾기"
        case .settings: "설정"
        }
    }
    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .archive: "calendar"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

enum IPadEditorSession: Identifiable {
    case moment(RecordDraft)
    case journal(JournalWritingDraft)

    var id: String {
        switch self {
        case .moment(let draft): "moment:\(draft.id)"
        case .journal(let draft): "journal:\(draft.id)"
        }
    }
}

/// The device gate lives in ContentView, so a narrow iPad window remains in the
/// iPad workspace instead of switching to the iPhone screen and losing its state.
struct IPadWorkspaceView: View {
    let recordStore: RecordStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selection: IPadSection? = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var editor: IPadEditorSession?
    @State private var isDraftListPresented = false
    @State private var pendingEditor: IPadEditorSession?
    @State private var archiveNavigation = IPadArchiveNavigation()
    @State private var searchNavigation = IPadSearchNavigation()
    @State private var selectedMomentID: UUID?
    @State private var isInspectorPresented = false

    var body: some View {
        GeometryReader { geometry in
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebar
                    .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 280)
            } detail: {
                destination
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: geometry.size.width, initial: true) { _, width in
                columnVisibility = width >= 1_000 && !dynamicTypeSize.isAccessibilitySize ? .all : .detailOnly
            }
            .onChange(of: dynamicTypeSize) { _, size in
                columnVisibility = geometry.size.width >= 1_000 && !size.isAccessibilitySize ? .all : .detailOnly
            }
        }
        .tint(Color.whisperAccent)
        // Attach the inspector to the workspace, outside the detail stack, so
        // the home stack retains its own native navigation bar and actions.
        .inspector(isPresented: $isInspectorPresented) {
            if let selectedMomentID, recordStore.record(withID: selectedMomentID) != nil {
                NavigationStack {
                    IPadEntryReader(entry: .moment(selectedMomentID), recordStore: recordStore, onEdit: {
                        closeSelection()
                        editor = $0
                    }, onDelete: closeSelection)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: closeSelection) { Image(systemName: "xmark") }
                                .accessibilityLabel("선택한 순간 닫기")
                        }
                    }
                }
                .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
            }
        }
        .onChange(of: selection) { _, _ in closeSelection() }
        .onChange(of: recordStore.records.map(\.id)) { _, ids in
            if let selectedMomentID, !ids.contains(selectedMomentID) { closeSelection() }
        }
        .fullScreenCover(item: $editor) { session in
            editorView(session)
                .interactiveDismissDisabled(recordStore.writingDraftStore.errorMessage != nil)
        }
        .sheet(isPresented: $isDraftListPresented, onDismiss: openPendingEditor) {
            WritingDraftListView(draftStore: recordStore.writingDraftStore, onOpenMoment: {
                pendingEditor = .moment($0)
                isDraftListPresented = false
            }, onOpenJournal: {
                pendingEditor = .journal($0)
                isDraftListPresented = false
            })
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                ForEach(IPadSection.allCases.filter { $0 != .settings }) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.symbol)
                            .font(.whisperControl)
                            .padding(.vertical, WhisperSpacing.xSmall)
                    }
                    .accessibilityIdentifier("ipad.sidebar.\(section.rawValue)")
                }
            }
            Section {
                Button { isDraftListPresented = true } label: {
                    Label("작성 중인 기록 · \(recordStore.writingDraftStore.count)", systemImage: "square.and.pencil")
                        .font(.whisperControl)
                        .padding(.vertical, WhisperSpacing.xSmall)
                }
                .accessibilityIdentifier("home.resumeDraftsButton")
                NavigationLink(value: IPadSection.settings) {
                    Label("설정", systemImage: "gearshape").font(.whisperControl)
                }
                .accessibilityIdentifier("ipad.sidebar.settings")
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.whisperSurfaceFocus)
        .navigationTitle("Whisper")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var destination: some View {
        switch selection ?? .today {
        case .today:
            NavigationStack {
                IPadHomeView(recordStore: recordStore, onAddMoment: {
                    editor = .moment(recordStore.writingDraftStore.momentDraft ?? RecordDraft())
                }, onCollect: { day in
                    editor = .journal(journalDraft(on: day))
                }, onResumeDrafts: { isDraftListPresented = true }, onSelectMoment: {
                    selectedMomentID = $0
                    isInspectorPresented = true
                }, onCloseSelection: closeSelection, isInspecting: isInspectorPresented)
            }
        case .archive:
            IPadArchiveView(recordStore: recordStore, navigation: archiveNavigation, onEdit: { editor = $0 })
        case .search:
            IPadSearchView(recordStore: recordStore, navigation: searchNavigation, onEdit: { editor = $0 })
        case .settings:
            NavigationStack { SettingsView(recordStore: recordStore) }
        }
    }

    @ViewBuilder
    private func editorView(_ session: IPadEditorSession) -> some View {
        switch session {
        case .moment(let initial):
            IPadMomentEditor(draft: initial, recordStore: recordStore)
        case .journal(let draft):
            IPadJournalEditor(draft: draft, recordStore: recordStore)
        }
    }

    private func journalDraft(on day: JournalDay) -> JournalWritingDraft {
        IPadDraftPreparation.journal(on: day, store: recordStore)
    }

    private func openPendingEditor() {
        editor = pendingEditor
        pendingEditor = nil
    }

    private func closeSelection() {
        isInspectorPresented = false
        selectedMomentID = nil
    }
}
