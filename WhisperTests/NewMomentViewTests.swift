import Observation
import SwiftUI
import Testing
import UIKit
import Vision
@testable import Whisper

@MainActor
@Observable
private final class NewMomentEditingState {
    var draft: RecordDraft
    init(_ draft: RecordDraft) { self.draft = draft }
}

@MainActor
@Suite("새 순간 작성과 초안 목록", .serialized)
struct NewMomentViewTests {
    @Test("새 작성 화면에 기존 글을 가져오지 않고 두 초안을 각각 이어 쓸 수 있다")
    func newEditorPreservesEarlierDraftAndListsBoth() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let earlier = RecordDraft(title: "첫 번째 초안", content: "기존에 쓰던 문장", emotion: "평온")
        #expect(store.writingDraftStore.save(earlier))
        // Select an emotion in the new draft so its native text editor is enabled.
        let fresh = RecordDraft(emotion: "기쁨")
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: editor(fresh, store: store))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            scene.windows.first { !$0.isHidden }?.makeKey()
        }
        try await settle()
        let input = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "record.contentField" })
        #expect(input.text.isEmpty)
        #expect(!textViews(in: host.view).contains { $0.text == earlier.content })
        input.text = "새로 시작한 문장"
        input.delegate?.textViewDidChange?(input)
        try await settle()
        #expect(store.writingDraftStore.count == 2)
        #expect(store.writingDraftStore.momentDrafts.first { $0.id == earlier.id } == earlier)
        #expect(store.writingDraftStore.momentDrafts.first { $0.id == fresh.id }?.content == "새로 시작한 문장")

        host.rootView = AnyView(EmptyView())
        try await settle()
        #expect(store.refreshPersistentState())
        host.rootView = AnyView(WritingDraftListView(draftStore: store.writingDraftStore,
            onOpenMoment: { _ in }, onOpenJournal: { _ in }))
        try await settle()
        let list = try renderedText(in: window)
        #expect(list.contains("기존에쓰던문장"))
        #expect(list.contains("새로시작한문장"))

        host.rootView = editor(earlier, store: store)
        try await settle()
        #expect(textViews(in: host.view).contains { $0.text == earlier.content })
        #expect(store.writingDraftStore.count == 2)
        #expect(store.writingDraftStore.momentDrafts.first { $0.id == fresh.id }?.content == "새로 시작한 문장")
    }

    private func editor(_ draft: RecordDraft, store: RecordStore) -> AnyView {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return AnyView(IPadMomentEditor(draft: draft, recordStore: store).id(draft.id))
        }
        let state = NewMomentEditingState(draft)
        return AnyView(QuickRecordView(draft: Binding(get: { state.draft }, set: { state.draft = $0 }),
            draftStore: store.writingDraftStore, onSave: { false }).id(draft.id))
    }

    private func settle() async throws { try await Task.sleep(for: .milliseconds(300)) }

    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }

    private func renderedText(in window: UIWindow) throws -> String {
        window.endEditing(true)
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image {
            _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: #require(image.cgImage), options: [:]).perform([request])
        return (request.results?.compactMap { $0.topCandidates(1).first?.string } ?? [])
            .joined().filter { !$0.isWhitespace }
    }
}
