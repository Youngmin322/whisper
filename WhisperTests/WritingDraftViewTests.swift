import Observation
import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Observable
private final class DraftEditingState {
    var draft: RecordDraft
    init(_ draft: RecordDraft) { self.draft = draft }
}

@MainActor
@Suite("작성 화면의 초안 생명주기", .serialized)
struct WritingDraftViewTests {
    @Test("순간 작성 화면은 입력 변경과 닫힘을 보관하고 다시 열 때 글과 사진을 유지한다")
    func momentViewAutosavesAndReopens() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let state = DraftEditingState(RecordDraft(content: "초기 문장", emotion: "기쁨", photoData: Data([1, 2, 3])))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: AnyView(QuickRecordView(
            draft: Binding(get: { state.draft }, set: { state.draft = $0 }),
            draftStore: store.writingDraftStore, onSave: { false })))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        try await settle()
        #expect(store.writingDraftStore.momentDraft == state.draft)

        state.draft.title = "작성 중 제목"
        state.draft.content = "닫아도 남아야 하는 최신 문장"
        try await settle()
        #expect(store.writingDraftStore.momentDraft == state.draft)
        host.rootView = AnyView(EmptyView())
        try await settle()
        #expect(store.refreshPersistentState())
        let restored = try #require(store.writingDraftStore.momentDraft)
        #expect(restored == state.draft)
        #expect(store.records.isEmpty)
        state.draft = restored
        host.rootView = AnyView(QuickRecordView(
            draft: Binding(get: { state.draft }, set: { state.draft = $0 }),
            draftStore: store.writingDraftStore, onSave: { false }))
        try await settle()
        #expect(store.writingDraftStore.momentDraft?.photoData == restored.photoData)
        #expect(textViews(in: host.view).contains { $0.text == restored.content })
    }

    @Test("일기 작성 화면에서 수정한 본문은 닫고 다시 열어도 복구되며 원본은 저장 전까지 그대로다")
    func journalViewAutosavesNativeTextInput() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let day = JournalDay(date: .now)
        let journal = try #require(store.saveJournal(on: day, title: "원래 제목", body: "원래 본문", sourceRecordIDs: [], emotion: "평온"))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: AnyView(NavigationStack { JournalEditorView(journal: journal, recordStore: store) }))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        try await settle()
        let textView = try #require(textViews(in: host.view).first { $0.text == "원래 본문" })
        textView.text = "쓰다가 닫은 일기"
        textView.delegate?.textViewDidChange?(textView)
        try await settle()
        #expect(store.writingDraftStore.journalDrafts.first?.body == "쓰다가 닫은 일기")
        #expect(journal.body == "원래 본문")
        host.rootView = AnyView(EmptyView())
        try await settle()
        host.rootView = AnyView(NavigationStack { JournalEditorView(journal: journal, recordStore: store) })
        try await settle()
        #expect(textViews(in: host.view).contains { $0.text == "쓰다가 닫은 일기" })
        #expect(store.writingDraftStore.journalDrafts.count == 1)
        #expect(store.journals.first?.body == "원래 본문")
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }
}
