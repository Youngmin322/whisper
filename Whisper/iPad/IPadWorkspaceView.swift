import SwiftUI
import UIKit
import Observation

enum IPadSection: String, CaseIterable, Identifiable {
    case today, archive, search, settings

    var id: Self { self }
    var title: String {
        switch self {
        case .today: String(localized: "오늘의 불꽃")
        case .archive: String(localized: "보관함")
        case .search: String(localized: "기억 찾기")
        case .settings: String(localized: "설정")
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

@Observable
final class IPadWorkspacePresentation {
    var selectedMoment: IPadEntry?
    var editor: IPadEditorSession?
    var pendingEditor: IPadEditorSession?

    func editSelectedMoment(_ session: IPadEditorSession) {
        pendingEditor = session
        selectedMoment = nil
    }

    func openPendingEditor() {
        guard let pendingEditor else { return }
        editor = pendingEditor
        self.pendingEditor = nil
    }
}

/// iPadOS owns the tab bar, sidebar, and their adaptation to the window size.
struct IPadWorkspaceView: View {
    let recordStore: RecordStore
    @State private var selection: IPadSection = .today
    @State private var isDraftListPresented = false
    @State private var archiveNavigation = IPadArchiveNavigation()
    @State private var searchNavigation = IPadSearchNavigation()
    @State private var presentation: IPadWorkspacePresentation

    init(recordStore: RecordStore, presentation: IPadWorkspacePresentation = IPadWorkspacePresentation()) {
        self.recordStore = recordStore
        _presentation = State(initialValue: presentation)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: IPadSection.today) {
                destination(.today)
            } label: {
                Label {
                    Text(IPadSection.today.title)
                } icon: {
                    Image(uiImage: Self.homeTabImage).renderingMode(.original)
                }
            }
            Tab(value: IPadSection.archive) {
                destination(.archive)
            } label: {
                Label {
                    Text(IPadSection.archive.title)
                } icon: {
                    Image("BottleLineIcon").renderingMode(.original)
                }
            }
            Tab(String(localized: "기억 찾기"), systemImage: "magnifyingglass", value: IPadSection.search, role: .search) {
                destination(.search)
            }
            Tab(String(localized: "설정"), systemImage: "gearshape", value: IPadSection.settings) {
                destination(.settings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(.tabBar)
        .tabViewSidebarFooter {
            Button(String(localized: "작성 중인 기록 · \(recordStore.writingDraftStore.count)")) { isDraftListPresented = true }
                .accessibilityIdentifier("home.resumeDraftsButton")
        }
        .tint(Color.whisperTextSecondary)
        .sheet(item: $presentation.selectedMoment, onDismiss: presentation.openPendingEditor) { entry in
            NavigationStack {
                IPadEntryReader(entry: entry, recordStore: recordStore,
                                onEdit: presentation.editSelectedMoment, onDelete: closeSelection)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "닫기"), action: closeSelection)
                            .accessibilityLabel(String(localized: "선택한 순간 닫기"))
                    }
                }
            }
            .presentationSizing(.page)
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selection) { _, _ in closeSelection() }
        .onChange(of: recordStore.records.map(\.id)) { _, ids in
            if case .moment(let id) = presentation.selectedMoment, !ids.contains(id) { closeSelection() }
        }
        .fullScreenCover(item: $presentation.editor) { session in
            editorView(session)
                .interactiveDismissDisabled(recordStore.writingDraftStore.errorMessage != nil)
        }
        .sheet(isPresented: $isDraftListPresented, onDismiss: presentation.openPendingEditor) {
            WritingDraftListView(draftStore: recordStore.writingDraftStore, onOpenMoment: {
                presentation.pendingEditor = .moment($0)
                isDraftListPresented = false
            }, onOpenJournal: {
                presentation.pendingEditor = .journal($0)
                isDraftListPresented = false
            })
        }
    }

    @ViewBuilder
    private func destination(_ section: IPadSection) -> some View {
        switch section {
        case .today:
            NavigationStack {
                IPadHomeView(recordStore: recordStore, onAddMoment: {
                    presentation.editor = .moment(RecordDraft())
                }, onCollect: { day in
                    presentation.editor = .journal(journalDraft(on: day))
                }, onResumeDrafts: { isDraftListPresented = true }, onSelectMoment: {
                    presentation.selectedMoment = .moment($0)
                }, onCloseSelection: closeSelection, isInspecting: presentation.selectedMoment != nil)
            }
        case .archive:
            IPadArchiveView(recordStore: recordStore, navigation: archiveNavigation, onEdit: { presentation.editor = $0 })
        case .search:
            IPadSearchView(recordStore: recordStore, navigation: searchNavigation, onEdit: { presentation.editor = $0 })
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

    private func closeSelection() {
        presentation.selectedMoment = nil
    }

    // Native tab items use the image's intrinsic size rather than a SwiftUI frame.
    // Keep the existing character, rendered at the size of a navigation icon.
    private static let homeTabImage: UIImage = {
        guard let source = UIImage(named: FlameCharacter.assetName(for: "기쁨")) else { return UIImage() }
        let canvas = CGSize(width: 24, height: 26)
        let scale = min(canvas.width / source.size.width, canvas.height / source.size.height)
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        return UIGraphicsImageRenderer(size: canvas).image { _ in
            source.draw(in: CGRect(x: (canvas.width - size.width) / 2,
                                  y: (canvas.height - size.height) / 2,
                                  width: size.width, height: size.height))
        }.withRenderingMode(.alwaysOriginal)
    }()
}
