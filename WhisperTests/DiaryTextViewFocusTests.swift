import Observation
import PhotosUI
import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Observable
private final class DiaryFocusState {
    var document = DiaryDocument(text: "사진을 고르기 전 쓰던 문장")
    var isFocused = true
    var isPhotoPickerPresented = false
    var selectedItem: PhotosPickerItem?
}

@MainActor
@Suite("사진 선택 중 본문 포커스", .serialized)
struct DiaryTextViewFocusTests {
    @Test("키보드를 내리고 사진 선택을 취소해도 본문과 커서를 유지하며 다시 입력한다")
    func presentsPhotoPickerAndResumesEditing() async throws {
        let state = DiaryFocusState()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: DiaryPhotoPickerFixture(state: state))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }
        try await settle()
        let editor = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "diary.body" })
        #expect(editor.isFirstResponder)
        editor.selectedRange = NSRange(location: 3, length: 0)
        let document = state.document
        let selection = editor.selectedRange

        state.isFocused = false
        state.isPhotoPickerPresented = true
        try await settle()
        #expect(!editor.isFirstResponder)
        #expect(!state.isFocused)
        #expect(viewControllers(in: host).contains { $0 is PHPickerViewController })
        #expect(state.document == document)
        #expect(editor.selectedRange == selection)

        state.isPhotoPickerPresented = false
        try await waitUntil { host.presentedViewController == nil && editor.isFirstResponder }
        #expect(host.presentedViewController == nil)
        #expect(editor.isFirstResponder)
        #expect(editor.selectedRange == selection)
        editor.insertText("이어서 ")
        try await settle()
        #expect(state.document.text == "사진을이어서  고르기 전 쓰던 문장")
    }

    @Test("대기 중인 포커스 요청은 최신 상태를 따르고 닫힌 편집기를 다시 활성화하지 않는다")
    func pendingFocusUsesLatestRequest() async throws {
        let state = DiaryFocusState()
        let owner = DiaryTextView(
            document: Binding(get: { state.document }, set: { state.document = $0 }),
            isFocused: Binding(get: { state.isFocused }, set: { state.isFocused = $0 }))
        let coordinator = DiaryTextView.Coordinator(owner)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        let host = UIViewController()
        let editor = UITextView(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        host.view.addSubview(editor)
        editor.delegate = coordinator
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }

        coordinator.updateFocus(in: editor)
        state.isFocused = false
        coordinator.updateFocus(in: editor)
        try await settle()
        #expect(!editor.isFirstResponder)
        #expect(!state.isFocused)

        state.isFocused = true
        coordinator.updateFocus(in: editor)
        try await settle()
        #expect(editor.isFirstResponder)

        state.isFocused = false
        coordinator.updateFocus(in: editor)
        // UIKit focus changes must wait until the SwiftUI update has returned.
        #expect(editor.isFirstResponder)
        try await settle()
        #expect(!editor.isFirstResponder)

        state.isFocused = true
        coordinator.updateFocus(in: editor)
        editor.removeFromSuperview()
        try await settle()
        #expect(!editor.isFirstResponder)
    }

    private func settle() async throws { try await Task.sleep(for: .milliseconds(600)) }

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

    private func viewControllers(in controller: UIViewController) -> [UIViewController] {
        [controller] + controller.children.flatMap { viewControllers(in: $0) }
            + (controller.presentedViewController.map { viewControllers(in: $0) } ?? [])
    }
}

private struct DiaryPhotoPickerFixture: View {
    @Bindable var state: DiaryFocusState

    var body: some View {
        NavigationStack {
            DiaryTextView(document: $state.document, isFocused: $state.isFocused, fillsHeight: true)
        }
        .photosPicker(isPresented: $state.isPhotoPickerPresented, selection: $state.selectedItem, matching: .images)
        .onChange(of: state.isPhotoPickerPresented) { _, isPresented in
            if !isPresented { state.isFocused = true }
        }
    }
}
