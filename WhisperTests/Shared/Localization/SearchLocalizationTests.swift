import SwiftUI
import Testing
import UIKit
import Vision
@testable import Whisper

@MainActor
@Suite("검색 화면의 앱 언어 표시", .serialized)
struct SearchLocalizationTests {
    @Test("빌드된 앱이 한국어·영어를 지원하고 기본 언어는 한국어다")
    func bundleSupportsKorean() {
        let bundle = Bundle.main
        #expect(bundle.developmentLocalization == "ko")
        #expect(bundle.localizations.contains("ko"))
        #expect(bundle.localizations.contains("en"))
        #expect(Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: ["ko-KR", "en"]).first == "ko")
        #expect(Bundle.preferredLocalizations(from: bundle.localizations, forPreferences: ["en-US", "ko"]).first == "en")
    }

    @Test("검색 시작·결과 없음·취소 문구가 앱 언어를 따르고 사용자 글은 유지된다")
    func searchUsesAppLanguage() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        _ = try #require(store.addAndReturn(title: "산책", content: "강변에서 걷던 오후", emotion: "평온"))
        _ = try #require(store.saveJournal(on: .now, title: "하루 일기", body: "기억하는 하루", sourceRecordIDs: []))
        let (window, host) = try makeHost(store: store)
        defer { close(window) }
        try await settle()
        let initial = try recognizedText(in: window, name: "initial")
        #expect(initial.contains(isEnglish ? "findamemory" : "기억찾기"))
        let search = try #require(searchController(in: host))
        search.isActive = true
        search.searchBar.becomeFirstResponder()
        try await settle()

        setQuery("없는 기억", in: search)
        try await settle()
        let empty = try recognizedText(in: window, name: "no-results")
        #expect(empty.contains(isEnglish ? (isPad ? "nomatchingrecords" : "noresults") : (isPad ? "기록이없어요" : "결과없음")))
        if !isEnglish { #expect(!empty.contains("noresults") && !empty.contains("checkthespelling") && !empty.contains("cancel")) }

        setQuery("강변", in: search)
        try await settle()
        let matched = try recognizedText(in: window, name: "matched")
        #expect(matched.contains("강변에서걷던오후"))
        #expect(!matched.contains("기억하는하루"))

        search.searchBar.delegate?.searchBarCancelButtonClicked?(search.searchBar)
        search.isActive = false
        try await settle()
        let cancelled = try recognizedText(in: window, name: "cancelled")
        #expect(search.searchBar.text?.isEmpty != false)
        #expect(cancelled.contains("강변에서걷던오후"))
        #expect(cancelled.contains("기억하는하루"))
    }

    @Test("기록이 없는 검색 화면도 앱 언어로 표시된다")
    func emptyArchiveUsesKorean() async throws {
        let (window, _) = try makeHost(store: RecordStore(isStoredInMemoryOnly: true))
        defer { close(window) }
        try await settle()
        let text = try recognizedText(in: window, name: "no-records")
        #expect(text.contains(isEnglish ? (isPad ? "whichmemory" : "nomemoriesyet") : (isPad ? "어떤기억" : "아직남긴기록")))
        if !isEnglish { #expect(!text.contains("noresults") && !text.contains("cancel")) }
    }

    private var isEnglish: Bool { WhisperLocalization.languageCode == "en" }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private func makeHost(store: RecordStore) throws -> (UIWindow, UIHostingController<AnyView>) {
        let root = isPad
            ? AnyView(IPadSearchView(recordStore: store, navigation: IPadSearchNavigation(), onEdit: { _ in }))
            : AnyView(NavigationStack { JournalMemorySearchView(recordStore: store) })
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: isPad ? 1194 : 393, height: isPad ? 834 : 852)
        window.overrideUserInterfaceStyle = .light
        let host = UIHostingController(rootView: AnyView(root.environment(\.locale, WhisperLocalization.locale)))
        window.rootViewController = host
        window.makeKeyAndVisible()
        return (window, host)
    }

    private func close(_ window: UIWindow) {
        let scene = window.windowScene
        window.isHidden = true
        window.rootViewController = nil
        scene?.windows.first { !$0.isHidden }?.makeKey()
    }

    private func searchController(in controller: UIViewController) -> UISearchController? {
        controller.navigationItem.searchController ?? controller.children.compactMap { searchController(in: $0) }.first
    }

    private func setQuery(_ query: String, in search: UISearchController) {
        search.searchBar.text = query
        search.searchBar.delegate?.searchBar?(search.searchBar, textDidChange: query)
    }

    private func settle() async throws { try await Task.sleep(for: .milliseconds(500)) }

    // Read the rendered screen: SwiftUI's system empty state is not a UILabel.
    private func recognizedText(in window: UIWindow, name: String) throws -> String {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(path: "SearchLocalizationCaptures")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(isPad ? "ipad" : "iphone")-\(name).png")
        try #require(image.pngData()).write(to: url)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: #require(image.cgImage), options: [:]).perform([request])
        let strings = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
        print("SEARCH_LANGUAGE \(name) preferences=\(Locale.preferredLanguages) bundle=\(Bundle.main.preferredLocalizations) strings=\(strings)")
        print("SEARCH_CAPTURE \(url.path)")
        return strings.joined().filter { !$0.isWhitespace }.lowercased()
    }
}
