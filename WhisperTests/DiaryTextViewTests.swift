import Observation
import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Observable
private final class DiaryScreenDraftState {
    var draft: RecordDraft
    init(_ draft: RecordDraft) { self.draft = draft }
}

@MainActor
@Suite("사진을 품은 다이어리 편집", .serialized)
struct DiaryTextViewTests {
    @Test("사진 앞뒤의 글을 편집하고 사진을 지워도 원문과 UTF-16 위치가 정확하다")
    func editsAroundNativeAttachment() throws {
        let photo = DiaryPhoto(offset: "오늘 👨‍👩‍👧\n".utf16.count, data: samplePhoto(), caption: "같이 걸은 오후")
        let document = DiaryDocument(text: "오늘 👨‍👩‍👧\n다시 떠올릴 문장", photos: [photo])
        let value = NSMutableAttributedString(attributedString: DiaryTextFormatter.attributed(document, width: 320, font: .systemFont(ofSize: 16)))
        #expect(DiaryTextFormatter.document(from: value) == document)
        value.insert(NSAttributedString(string: "처음의 마음\n"), at: 0)
        let edited = DiaryTextFormatter.document(from: value)
        #expect(edited.text == "처음의 마음\n" + document.text)
        #expect(edited.photos.first?.id == photo.id)
        #expect(edited.photos.first?.offset == photo.offset + "처음의 마음\n".utf16.count)
        value.deleteCharacters(in: NSRange(location: edited.photos[0].offset, length: 1))
        let removed = DiaryTextFormatter.document(from: value)
        #expect(removed.text == edited.text)
        #expect(removed.photos.isEmpty)
    }

    @Test("동일한 위치의 여러 사진은 순서와 독립된 사진 데이터를 유지한다")
    func keepsPhotoOrderAndArchivedAttachment() throws {
        let photos = [DiaryPhoto(offset: 1, data: samplePhoto()), DiaryPhoto(offset: 1, data: samplePhoto(), caption: "두 번째")]
        let document = DiaryDocument(text: "앞뒤", photos: photos)
        let native = DiaryTextFormatter.attributed(document, width: 320, font: .systemFont(ofSize: 16))
        #expect(DiaryTextFormatter.document(from: native) == document)
        let attachment = try #require(native.attribute(.attachment, at: 1, effectiveRange: nil) as? DiaryPhotoAttachment)
        let archive = try NSKeyedArchiver.archivedData(withRootObject: attachment, requiringSecureCoding: true)
        let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: DiaryPhotoAttachment.self, from: archive)
        let restored = try #require(decoded)
        #expect(restored.photo == photos[0])
    }

    @Test("사진 확대 화면은 확대 후 실제 스크롤 영역이 커진다")
    func zoomAllowsPanning() throws {
        let image = try #require(UIImage(data: samplePhoto()))
        let view = DiaryPhotoZoomScrollView(image: image)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 600)
        view.layoutIfNeeded()
        #expect(view.zoomScale == view.minimumZoomScale)
        view.setZoomScale(view.minimumZoomScale * 3, animated: false)
        view.layoutIfNeeded()
        #expect(view.contentSize.width > view.bounds.width)
        #expect(view.contentSize.height > view.bounds.height)
    }

    @Test("일기 편집과 기록 읽기는 사진을 같은 본문 안에 배치하고 저장한 사진을 재사용한다")
    func nativeScreensKeepInlinePhotos() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let firstText = "오늘은 조금 천천히 걸었다.\n함께 걸으니 평범한 길도 다르게 보였다.\n\n"
        let lastText = "바쁜 하루였지만 이런 순간이 남아서 좋다.\n내일도 작은 기쁨을 놓치지 않고 싶다."
        let source = try #require(store.addAndReturn(title: "같이 걸은 오후", content: firstText + lastText,
                                                     emotion: "기쁨", photoData: samplePhoto()))
        let document = DiaryDocument(text: source.content, photos: [DiaryPhoto(offset: firstText.utf16.count,
            data: source.photoData, sourceRecordID: source.id, caption: source.title)])
        #expect(store.update(source, title: source.title, content: source.content, emotion: source.emotion,
                             photoData: source.photoData, document: document))
        let day = JournalDay(date: source.createdAt)
        var draft = store.prepareJournalDraft(JournalWritingDraft(day: day, existing: nil, records: [source]), existing: nil)
        draft.title = "천천히 걸어서 좋았던 하루"
        let journal = try #require(store.saveJournalDraft(draft))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: AnyView(NavigationStack { RecordDetailView(record: source, recordStore: store) }))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        try await settle()
        let recordBody = try #require(textViews(in: host.view).first)
        #expect(!recordBody.isEditable)
        #expect(DiaryTextFormatter.document(from: recordBody.attributedText).photos.count == 1)
        capture(window, name: "diary-record")

        host.rootView = AnyView(NavigationStack { JournalDetailView(journalID: journal.id, recordStore: store) })
        try await settle()
        let readingBody = try #require(textViews(in: host.view).first)
        #expect(DiaryTextFormatter.document(from: readingBody.attributedText) == draft.document)
        capture(window, name: "diary-day")

        host.rootView = AnyView(NavigationStack { JournalEditorView(journal: journal, recordStore: store) })
        try await settle()
        let editor = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "journal.bodyField" })
        #expect(editor.isEditable)
        #expect(!editor.isScrollEnabled)
        #expect(DiaryTextFormatter.document(from: editor.attributedText) == draft.document)
        capture(window, name: "diary-day-editor")
        editor.selectedRange = NSRange(location: 0, length: 0)
        editor.insertText("마음을 다듬으며, ")
        try await settle()
        let autosaved = try #require(store.writingDraftStore.journalDrafts.first)
        #expect(autosaved.document?.photos.first?.offset == firstText.utf16.count + "마음을 다듬으며, ".utf16.count)
        #expect(autosaved.document?.photos.first?.data == source.photoData)
        #expect(source.content == document.text)
        #expect(journal.body == document.text)
    }

    @Test("순간 작성에서도 사진 앞뒤로 쓰고 삭제하면 첨부와 초안이 함께 바뀐다")
    func momentPhotoEditingAndDeletion() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let before = "오늘은 조금 천천히 걸었다.\n함께 걸으니 평범한 길도 다르게 보였다.\n\n"
        let after = "바쁜 하루였지만 이런 순간이 남아서 좋다."
        let document = DiaryDocument(text: before + after,
                                     photos: [DiaryPhoto(offset: before.utf16.count, data: samplePhoto())])
        var draft = RecordDraft(title: "같이 걸은 오후", emotion: "기쁨")
        draft.setDiaryDocument(document)
        let state = DiaryScreenDraftState(draft)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: QuickRecordView(
            draft: Binding(get: { state.draft }, set: { state.draft = $0 }),
            draftStore: store.writingDraftStore, onSave: { false }))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        try await settle()
        let editor = try #require(textViews(in: host.view).first)
        try await waitForFocus(editor)
        #expect(DiaryTextFormatter.document(from: editor.attributedText).photos.count == 1)
        editor.resignFirstResponder()
        try await settle()
        capture(window, name: "diary-moment-editor")
        editor.selectedRange = NSRange(location: before.utf16.count + 1, length: 0)
        editor.insertText("사진 뒤에 덧붙인 마음, ")
        try await settle()
        #expect(state.draft.content == before + "사진 뒤에 덧붙인 마음, " + after)
        #expect(state.draft.diaryDocument.photos.first?.offset == before.utf16.count)
        editor.selectedRange = NSRange(location: before.utf16.count, length: 1)
        editor.deleteBackward()
        try await settle()
        #expect(state.draft.photoData == nil)
        #expect(state.draft.diaryDocument.photos.isEmpty)
        #expect(store.writingDraftStore.momentDraft == state.draft)
        #expect(store.records.isEmpty)
    }

    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }
    private func settle() async throws { try await Task.sleep(for: .milliseconds(350)) }

    private func waitForFocus(_ editor: UITextView) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !editor.isFirstResponder, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(editor.isFirstResponder)
    }
    private func capture(_ window: UIWindow, name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let url = FileManager.default.temporaryDirectory.appending(path: "\(name).png")
        try? image.pngData()?.write(to: url)
        print("Diary UI capture: \(url.path)")
    }
    /// An illustration fixture; no personal photos are added to the test store.
    private func samplePhoto() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600)).image { renderer in
            let context = renderer.cgContext
            let colors = [UIColor(red: 0.93, green: 0.84, blue: 0.69, alpha: 1).cgColor,
                          UIColor(red: 0.64, green: 0.72, blue: 0.60, alpha: 1).cgColor] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 600), options: [])
            UIColor(red: 0.98, green: 0.94, blue: 0.77, alpha: 1).setFill()
            context.fillEllipse(in: CGRect(x: 510, y: 70, width: 90, height: 90))
            UIColor(red: 0.38, green: 0.50, blue: 0.40, alpha: 1).setFill()
            let hills = UIBezierPath()
            hills.move(to: CGPoint(x: 0, y: 350))
            hills.addCurve(to: CGPoint(x: 800, y: 370), controlPoint1: CGPoint(x: 240, y: 130), controlPoint2: CGPoint(x: 520, y: 500))
            hills.addLine(to: CGPoint(x: 800, y: 600)); hills.addLine(to: CGPoint(x: 0, y: 600)); hills.close(); hills.fill()
            UIColor(red: 0.79, green: 0.72, blue: 0.58, alpha: 1).setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 420, y: 400)); path.addCurve(to: CGPoint(x: 210, y: 600), controlPoint1: CGPoint(x: 650, y: 500), controlPoint2: CGPoint(x: 250, y: 510))
            path.lineWidth = 35; path.stroke()
        }.jpegData(compressionQuality: 0.85)!
    }
}
