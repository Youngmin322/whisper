import Observation
import SwiftData
import SwiftUI
import Testing
import UIKit
import Vision
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
    @Test("초안 목록은 읽기 불가 안내와 재시도를 표시하고 정상 초안을 계속 노출한다", arguments: [false, true])
    func listsUnreadableDraftsWithoutAnEmptyState(onlyUnreadable: Bool) async throws {
        let schema = Schema(versionedSchema: WhisperSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let drafts = WritingDraftStore(context: context)
        if !onlyUnreadable {
            #expect(drafts.save(RecordDraft(title: "정상초안", content: "계속 작성할 내용", emotion: "기쁨")))
        }
        let id = UUID()
        context.insert(WritingDraft(id: id, storageKey: "moment:new:\(id.uuidString)", payload: Data([0])))
        try context.save()
        drafts.reload()

        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 600, height: 1000)
        let host = UIHostingController(rootView: WritingDraftListView(draftStore: drafts, onOpenMoment: { _ in }, onOpenJournal: { _ in }))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            scene.windows.first { !$0.isHidden }?.makeKey()
        }
        try await settle()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image {
            _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let cgImage = try #require(image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["ko-KR", "en-US"]
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().filter { !$0.isWhitespace }
        let english = WhisperLocalization.languageCode == "en"
        #expect(text.contains(english ? "Draftsthatcouldnotbeopened" : "읽을수없는초안"))
        #expect(text.contains(english ? "Reloaddrafts" : "초안다시불러오기"))
        #expect(!text.contains(english ? "Nodraftsinprogress" : "작성중인초안이없어요"))
        if !onlyUnreadable { #expect(text.contains("정상초안")) }
        if let directory = ProcessInfo.processInfo.environment["WHISPER_SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try image.pngData()?.write(to: url.appending(path: "unreadable-drafts-\(onlyUnreadable).png"))
        }
    }

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

    @Test("기존 순간 수정 화면은 변경한 본문을 닫을 때 보관하고 이어 쓰며 원본을 유지한다")
    func momentEditAutosavesAndReopens() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let record = try #require(store.addAndReturn(title: "원래 제목", content: "원래 본문", emotion: "평온", photoData: Data([1, 2])))
        let initial = RecordDraft(title: record.title, content: record.content, emotion: record.emotion,
            photoData: record.photoData, document: store.diaryDocument(for: record).withoutPhotoData, existingRecordID: record.id)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: AnyView(NavigationStack {
            RecordDetailView(record: record, recordStore: store, editingDraft: initial)
        }))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        try await settle()
        #expect(store.writingDraftStore.count == 0)
        let textView = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "record.editContentField" })
        textView.text = "쓰다가 닫은 순간 수정"
        textView.delegate?.textViewDidChange?(textView)
        try await settle()
        let edit = try #require(store.writingDraftStore.momentEditDraft(for: record.id))
        #expect(edit.content == "쓰다가 닫은 순간 수정")
        #expect(edit.emotion == "평온")
        #expect(edit.photoData == Data([1, 2]))
        #expect(record.content == "원래 본문")
        host.rootView = AnyView(EmptyView())
        try await settle()
        #expect(store.refreshPersistentState())
        let restored = try #require(store.writingDraftStore.momentEditDraft(for: record.id))
        host.rootView = AnyView(NavigationStack {
            RecordDetailView(record: record, recordStore: store, editingDraft: restored)
        })
        try await settle()
        #expect(textViews(in: host.view).contains { $0.text == "쓰다가 닫은 순간 수정" })
        #expect(store.writingDraftStore.momentDraft == nil)
        #expect(store.records.first?.content == "원래 본문")
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(200))
    }

    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }
}
