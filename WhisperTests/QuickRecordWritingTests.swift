import Observation
import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Observable
private final class MomentWritingState {
    var draft: RecordDraft
    init(_ draft: RecordDraft) { self.draft = draft }
}

@MainActor
@Suite("순간 작성 화면의 입력과 사진 보존", .serialized)
struct QuickRecordWritingTests {
    @Test("여러 사진을 본문에 붙이고 한 장을 지워도 나머지 사진과 초안이 유지된다")
    func rendersMultiplePhotosAndDeletesOnlyOne() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let state = MomentWritingState(RecordDraft(content: "앞뒤", emotion: "기쁨"))
        let loader = PhotoAttachmentLoader()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        let (window, host) = makeHost(state, store: store, scene: scene, loader: loader)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        try await settle()
        let editor = try #require(textViews(in: host.view).first)
        editor.selectedRange = NSRange(location: 1, length: 0)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        }
        let data = try #require(image.pngData())
        let request = loader.loadBatch(transfers: [{ data }, { data }])
        await request.value
        try await settle()
        let rendered = DiaryTextFormatter.document(from: editor.attributedText)
        #expect(rendered.text == "앞뒤")
        #expect(rendered.photos.count == 2)
        #expect(rendered.photos.map(\.offset) == [1, 1])
        #expect(rendered.photos.map(\.data) == state.draft.diaryDocument.photos.map(\.data))
        #expect(Set(rendered.photos.map(\.id)).count == 2)

        editor.selectedRange = NSRange(location: 2, length: 1)
        editor.deleteBackward()
        try await settle()
        #expect(state.draft.content == "앞뒤")
        #expect(state.draft.diaryDocument.photos.map(\.id) == [rendered.photos[0].id])
        #expect(state.draft.photoData == rendered.photos[0].data)
        #expect(store.writingDraftStore.momentDraft == state.draft)

        let additional = loader.loadBatch(transfers: [{ data }])
        await additional.value
        try await settle()
        #expect(state.draft.diaryDocument.photos.count == 2)
        #expect(state.draft.diaryDocument.photos.contains { $0.id == rendered.photos[0].id })
        #expect(Set(state.draft.diaryDocument.photos.map(\.id)).count == 2)
        #expect(store.writingDraftStore.momentDraft == state.draft)
        // Finish the keyboard transition before the next hosted screen uses the scene.
        editor.resignFirstResponder()
        host.rootView = AnyView(EmptyView())
        try await settle()
    }

    @Test("감정 선택 후 빈 본문에 바로 입력하고 화면 높이가 바뀌어도 커서와 초안을 유지한다", arguments: [false, true])
    func focusesEmptyEditorAndPreservesInputDuringResize(largeText: Bool) async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let state = MomentWritingState(RecordDraft())
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let (window, host) = makeHost(state, store: store, scene: scene, largeText: largeText)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKey()
        }
        try await settle()
        #expect(textViews(in: host.view).isEmpty)

        state.draft.emotion = "기쁨"
        try await waitUntil { textViews(in: host.view).first?.isFirstResponder == true }
        let editor = try #require(textViews(in: host.view).first)
        #expect(editor.isFirstResponder)
        #expect(editor.text.isEmpty)
        #expect(!state.draft.canSaveNewMoment)
        editor.insertText("오늘은 잠깐 멈춰 쉬었다.")
        try await settle()
        #expect(state.draft.content == "오늘은 잠깐 멈춰 쉬었다.")
        #expect(store.writingDraftStore.momentDraft?.content == state.draft.content)
        #expect(state.draft.canSaveNewMoment)

        let selection = editor.selectedRange
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        host.additionalSafeAreaInsets.bottom = 260
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        try await settle()
        #expect(textViews(in: host.view).first === editor)
        #expect(editor.selectedRange == selection)
        #expect(editor.isFirstResponder)
        #expect(editor.bounds.height >= 44)
        let cursor = try #require(editor.selectedTextRange).end
        let cursorFrame = editor.convert(editor.caretRect(for: cursor), to: host.view)
        #expect(cursorFrame.maxY <= host.view.bounds.height - 260)
        var ancestor = editor.superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                let viewport = scrollView.convert(scrollView.bounds, to: host.view)
                #expect(viewport.contains(cursorFrame))
            }
            ancestor = view.superview
        }
        #expect(store.records.isEmpty)
    }

    @Test("감정 변경 중에도 화면이 소유한 사진 전송을 이어 가고 본문·제목과 함께 초안에 보관한다")
    func emotionChangeKeepsTransferAndDraft() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let state = MomentWritingState(RecordDraft(title: "남겨 둘 제목", content: "쓰고 있던 문장", emotion: "기쁨"))
        let loader = PhotoAttachmentLoader()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let (window, host) = makeHost(state, store: store, scene: scene, loader: loader)
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        try await settle()

        let photo = Data([10, 20, 30])
        let secondPhoto = Data([40, 50, 60])
        let transfer = loader.loadBatch(transfers: [{
            try await Task.sleep(for: .seconds(1))
            return photo
        }, { secondPhoto }], process: { $0 })
        #expect(loader.isLoading)
        state.draft.emotion = "평온"
        let editor = try #require(textViews(in: host.view).first)
        editor.text = "감정을 바꾼 뒤에도 이어 쓰는 문장"
        editor.delegate?.textViewDidChange?(editor)
        try await settle()
        #expect(loader.isLoading)
        #expect(state.draft.photoData == nil)
        await transfer.value
        try await settle()
        #expect(!loader.isLoading)
        #expect(state.draft.photoData == photo)
        #expect(state.draft.diaryDocument.photos.map(\.data) == [photo, secondPhoto])
        #expect(state.draft.title == "남겨 둘 제목")
        #expect(state.draft.emotion == "평온")
        #expect(state.draft.content == "감정을 바꾼 뒤에도 이어 쓰는 문장")
        #expect(store.writingDraftStore.momentDraft == state.draft)
        #expect(store.records.isEmpty)
    }

    private func makeHost(_ state: MomentWritingState, store: RecordStore,
                          scene: UIWindowScene, loader: PhotoAttachmentLoader? = nil, largeText: Bool = false)
        -> (UIWindow, UIHostingController<AnyView>) {
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: AnyView(QuickRecordView(
            draft: Binding(get: { state.draft }, set: { state.draft = $0 }),
            draftStore: store.writingDraftStore, photoLoader: loader, onSave: { false })
            .environment(\.dynamicTypeSize, largeText ? .accessibility5 : .large)))
        window.rootViewController = host
        return (window, host)
    }

    private func settle() async throws { try await Task.sleep(for: .milliseconds(350)) }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(condition())
    }

    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }
}
