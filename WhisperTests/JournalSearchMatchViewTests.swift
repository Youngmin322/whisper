import SwiftUI
import Testing
import UIKit
import Vision
@testable import Whisper

@MainActor
@Suite("검색한 일기와 원본 문장 표시", .serialized)
struct JournalSearchMatchViewTests {
    @Test("iPhone 검색 미리보기와 일기 화면에 일치한 원본 문장을 표시한다", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
    func phonePreviewAndJournalSources() async throws {
        let (store, journal, _) = try sample()
        let result = try #require(JournalArchiveIndex(records: store.records, journals: store.journals).results(matching: "민수").first)
        let (window, host) = try makeHost(NavigationStack { JournalMemorySearchView(recordStore: store) }, size: CGSize(width: 393, height: 852))
        defer { close(window) }
        try await settle()
        let search = try #require(searchController(in: host))
        search.isActive = true
        search.searchBar.becomeFirstResponder()
        try await settle()
        search.searchBar.text = "민수"
        search.searchBar.delegate?.searchBar?(search.searchBar, textDidChange: "민수")
        search.searchBar.resignFirstResponder()
        try await settle()
        #expect(search.searchBar.text == "민수")
        let preview = try capture(window, name: "iphone-results")
        #expect(preview.contains("편안한하루"))
        #expect(preview.contains("담아둔순간에서찾았어요"))
        #expect(preview.contains("민수와강변에서산책했다"))
        host.rootView = themed(NavigationStack {
            JournalDetailView(journalID: result.recordID, recordStore: store, searchContext: result.searchContext)
        })
        try await settle()
        let reader = try capture(window, name: "iphone-journal")
        #expect(textViews(in: host.view).contains { $0.text == journal.body && !$0.isEditable })
        #expect(reader.contains("민수와강변에서산책했다"))
    }

    @Test("일기 본문에서 찾으면 원본은 접어 두고 검색 없이 열 때도 접어 둔다", .enabled(if: UIDevice.current.userInterfaceIdiom == .phone))
    func ordinaryAndBodyMatchReadersKeepSourcesCollapsed() async throws {
        let (store, journal, _) = try sample()
        let result = try #require(JournalArchiveIndex(records: store.records, journals: store.journals).results(matching: "편안").first)
        let (window, host) = try makeHost(NavigationStack {
            JournalDetailView(journalID: journal.id, recordStore: store, searchContext: result.searchContext)
        }, size: CGSize(width: 393, height: 852))
        defer { close(window) }
        try await settle()
        let bodyMatch = try capture(window, name: "iphone-body-match")
        #expect(!bodyMatch.contains("민수와강변에서산책했다"))
        host.rootView = themed(NavigationStack { JournalDetailView(journalID: journal.id, recordStore: store) })
        try await settle()
        let ordinary = try capture(window, name: "iphone-ordinary")
        #expect(!ordinary.contains("민수와강변에서산책했다"))
    }

    @Test("iPad에서는 검색한 일기와 펼친 원본을 넓은 창·좁은 창에서 유지하고 원본 삭제 후 선택을 비운다", .enabled(if: UIDevice.current.userInterfaceIdiom == .pad))
    func padSelectionSurvivesResizeAndClearsDeletedMatch() async throws {
        let (store, journal, source) = try sample()
        let state = IPadSearchNavigation()
        state.query = "민수"
        let (window, host) = try makeHost(IPadSearchView(recordStore: store, navigation: state, onEdit: { _ in }), size: CGSize(width: 1194, height: 834))
        defer { close(window) }
        try await settle()
        let results = try capture(window, name: "ipad-results")
        #expect(results.contains("민수와강변에서산책했다"))
        state.selection = .journal(journal.id)
        try await settle()
        #expect(textViews(in: host.view).contains { $0.text == journal.body })
        let wide = try capture(window, name: "ipad-journal-wide")
        #expect(wide.contains("민수와강변에서산책했다"))
        window.frame.size = CGSize(width: 600, height: 834)
        try await settle()
        #expect(state.path == [.journal(journal.id)])
        #expect(textViews(in: host.view).contains { $0.text == journal.body })
        let narrow = try capture(window, name: "ipad-journal-narrow")
        #expect(narrow.contains("민수와강변에서산책했다"))
        window.frame.size = CGSize(width: 1194, height: 834)
        try await settle()
        state.query = "편안"
        try await settle()
        #expect(state.selection == .journal(journal.id))
        let bodyMatch = try capture(window, name: "ipad-body-match")
        #expect(!bodyMatch.contains("민수와강변에서산책했다"))
        state.query = "민수"
        try await settle()
        #expect(store.delete(source))
        try await settle()
        #expect(state.selection == nil && state.path.isEmpty)
        #expect(!textViews(in: host.view).contains { $0.text == journal.body })
    }

    private func sample() throws -> (RecordStore, DailyJournal, WhisperRecord) {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let source = try #require(store.addAndReturn(title: "오후 산책", content: "민수와 강변에서 산책했다."))
        let journal = try #require(store.saveJournal(on: .now, title: "편안한 하루", body: "오늘은 편안했다.", sourceRecordIDs: [source.id]))
        return (store, journal, source)
    }

    private func makeHost<V: View>(_ root: V, size: CGSize) throws -> (UIWindow, UIHostingController<AnyView>) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = .light
        let host = UIHostingController(rootView: themed(root))
        window.rootViewController = host
        window.makeKeyAndVisible()
        return (window, host)
    }
    private func themed<V: View>(_ root: V) -> AnyView { AnyView(root.tint(Color.whisperAccent)) }
    private func close(_ window: UIWindow) {
        let scene = window.windowScene
        window.isHidden = true
        window.rootViewController = nil
        scene?.windows.first { !$0.isHidden }?.makeKey()
    }
    private func settle() async throws { try await Task.sleep(for: .milliseconds(500)) }
    private func searchController(in controller: UIViewController) -> UISearchController? {
        controller.navigationItem.searchController ?? controller.children.compactMap { searchController(in: $0) }.first
    }
    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }
    private func capture(_ window: UIWindow, name: String) throws -> String {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(path: "JournalSearchMatchCaptures")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(name).png")
        try #require(image.pngData()).write(to: url)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: #require(image.cgImage), options: [:]).perform([request])
        let strings = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
        print("JOURNAL_SEARCH_CAPTURE \(url.path) text=\(strings)")
        return strings.joined().filter { !$0.isWhitespace }
    }
}
