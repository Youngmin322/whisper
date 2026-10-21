import Observation
import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Observable
private final class DiaryGestureState {
    var document: DiaryDocument
    var isFocused = false
    var openedPhoto: DiaryPhoto?

    init(document: DiaryDocument) { self.document = document }
}

@MainActor
@Suite("본문 커서 이동과 사진 터치", .serialized)
struct DiaryTextViewGestureTests {
    @Test("사진 확대는 글자와 빈 공간의 터치를 가로채지 않는다", arguments: [false, true])
    func textTouchesRemainAvailableToNativeSelection(fillsHeight: Bool) async throws {
        let state = DiaryGestureState(document: DiaryDocument(text: "처음 적은 문장\n다시 고칠 문장"))
        let (window, host, previousWindow) = try makeHost(state, fillsHeight: fillsHeight)
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        try await settle()
        state.isFocused = true
        try await settle()
        let editor = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "diary.body" })
        let tap = try #require(photoTap(in: editor))
        let delegate = try #require(tap.delegate)
        let start = try #require(editor.position(from: editor.beginningOfDocument, offset: 3))
        let caret = editor.caretRect(for: start)
        #expect(delegate.gestureRecognizer?(tap, shouldReceive: DiaryTouch(at: CGPoint(x: caret.midX, y: caret.midY))) == false)
        #expect(delegate.gestureRecognizer?(tap, shouldReceive: DiaryTouch(at: CGPoint(x: editor.bounds.maxX - 1, y: caret.midY))) == false)
        #expect(delegate.gestureRecognizer?(tap, shouldReceive: DiaryTouch(at: CGPoint(x: 8, y: editor.bounds.maxY - 1))) == false)
        #expect(state.openedPhoto == nil)
    }

    @Test("사진 앞 문장으로 커서를 옮겨 편집해도 사진 위치와 선택한 커서를 보존한다", arguments: [false, true])
    func editsEarlierTextWithoutLosingPhotos(fillsHeight: Bool) async throws {
        let before = "처음 적은 문장\n"
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let photo = DiaryPhoto(offset: before.utf16.count, data: image.pngData())
        let tail = String(repeating: "이어서 적은 문장입니다.\n", count: 25)
        let state = DiaryGestureState(document: DiaryDocument(text: before + tail, photos: [photo]))
        let (window, host, previousWindow) = try makeHost(state, fillsHeight: fillsHeight)
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        try await settle()
        state.isFocused = true
        try await settle()
        let editor = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "diary.body" })
        let tap = try #require(photoTap(in: editor))
        let delegate = try #require(tap.delegate)
        #expect(DiaryTextFormatter.document(from: editor.attributedText) == state.document)
        editor.layoutManager.ensureLayout(for: editor.textContainer)
        let glyphs = editor.layoutManager.glyphRange(forCharacterRange: NSRange(location: before.utf16.count, length: 1), actualCharacterRange: nil)
        let photoRect = editor.layoutManager.boundingRect(forGlyphRange: glyphs, in: editor.textContainer)
        let photoPoint = CGPoint(x: photoRect.midX + editor.textContainerInset.left,
                                 y: photoRect.midY + editor.textContainerInset.top)
        #expect(delegate.gestureRecognizer?(tap, shouldReceive: DiaryTouch(at: photoPoint)) == true)
        #expect(delegate.gestureRecognizer?(tap, shouldReceive: DiaryTouch(at: CGPoint(x: photoPoint.x, y: photoRect.minY - 10))) == false)

        editor.selectedRange = NSRange(location: editor.attributedText.length, length: 0)
        editor.scrollRangeToVisible(editor.selectedRange)
        editor.selectedRange = NSRange(location: 3, length: 0)
        let caret = editor.caretRect(for: try #require(editor.selectedTextRange).start)
        #expect(delegate.gestureRecognizer?(tap, shouldReceive: DiaryTouch(at: CGPoint(x: caret.midX, y: caret.midY))) == false)
        editor.insertText("고친 ")
        try await settle()
        #expect(state.document.text == "처음 고친 적은 문장\n" + tail)
        #expect(state.document.photos.first?.id == photo.id)
        #expect(state.document.photos.first?.data == photo.data)
        #expect(state.document.photos.first?.offset == photo.offset + "고친 ".utf16.count)
        #expect(editor.selectedRange == NSRange(location: 6, length: 0))
        #expect(editor.isFirstResponder)
        #expect(state.openedPhoto == nil)
    }

    private func makeHost(_ state: DiaryGestureState, fillsHeight: Bool) throws -> (UIWindow, UIHostingController<AnyView>, UIWindow?) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: AnyView(DiaryGestureFixture(state: state, fillsHeight: fillsHeight)))
        window.rootViewController = host
        window.makeKeyAndVisible()
        return (window, host, previousWindow)
    }

    private func photoTap(in editor: UITextView) -> UITapGestureRecognizer? {
        editor.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first {
            $0.name == "diary.photoTap"
        }
    }

    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }

    private func settle() async throws { try await Task.sleep(for: .milliseconds(350)) }
}

private struct DiaryGestureFixture: View {
    @Bindable var state: DiaryGestureState
    let fillsHeight: Bool

    var body: some View {
        ScrollView {
            DiaryTextView(document: $state.document, isFocused: $state.isFocused,
                          fillsHeight: fillsHeight, minimumHeight: 300,
                          onPhotoTap: { state.openedPhoto = $0 })
                .frame(width: 333, height: fillsHeight ? 400 : nil)
                .padding(30)
        }
    }
}

private final class DiaryTouch: UITouch {
    private let point: CGPoint
    init(at point: CGPoint) { self.point = point; super.init() }
    override func location(in view: UIView?) -> CGPoint { point }
}
