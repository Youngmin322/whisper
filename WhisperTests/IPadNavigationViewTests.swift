import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("iPad 선택과 적응형 탐색", .serialized)
struct IPadNavigationViewTests {
    @Test("보관함은 선택 전 본문을 열지 않고, 선택한 기록을 좁은 창과 넓은 창에서 이어 보여준다")
    func archiveSelectionSurvivesResize() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let day = JournalDay(date: .now)
        let journal = try #require(store.saveJournal(on: day, title: "하루", body: "선택한 뒤에만 펼쳐지는 본문", sourceRecordIDs: []))
        let state = IPadArchiveNavigation()
        let (window, host) = try makeHost(IPadArchiveView(recordStore: store, navigation: state, onEdit: { _ in }))
        defer { close(window) }
        try await settle()
        #expect(!textViews(in: host.view).contains { $0.text.contains(journal.body) })
        state.day = day
        state.selection = .journal(journal.id)
        try await settle()
        #expect(textViews(in: host.view).contains { $0.text == journal.body })
        window.frame.size = CGSize(width: 600, height: 834)
        try await settle()
        #expect(state.path == [.journal(journal.id)])
        #expect(state.day == day)
        #expect(textViews(in: host.view).contains { $0.text == journal.body })
        window.frame.size = CGSize(width: 1194, height: 834)
        try await settle()
        #expect(state.path.isEmpty)
        #expect(state.selection == .journal(journal.id))
        #expect(textViews(in: host.view).contains { $0.text == journal.body })
    }

    @Test("검색어가 바뀌어 선택한 기록이 결과에서 빠지면 읽기 패널도 비워진다")
    func searchClearsAnUnrelatedSelection() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let record = try #require(store.addAndReturn(title: "바다", content: "바다에서 걸었다.", emotion: "평온"))
        let state = IPadSearchNavigation()
        let (window, host) = try makeHost(IPadSearchView(recordStore: store, navigation: state, onEdit: { _ in }))
        defer { close(window) }
        try await settle()
        #expect(textViews(in: host.view).isEmpty)
        state.query = "바다"
        state.selection = .moment(record.id)
        try await settle()
        #expect(textViews(in: host.view).contains { $0.text == record.content })
        state.query = "결과가 없는 검색어"
        try await settle()
        #expect(state.selection == nil)
        #expect(state.path.isEmpty)
        #expect(!textViews(in: host.view).contains { $0.text == record.content })
    }

    @Test("가로·세로·좁은 창·큰 글자 화면을 네이티브 렌더로 검토한다", .enabled(if: UIDevice.current.userInterfaceIdiom == .pad))
    func captureResponsiveScreens() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        for (i, emotion) in ["기쁨", "평온", "불안", "슬픔"].enumerated() {
            _ = try #require(store.addAndReturn(title: "오늘의 작은 순간 \(i + 1)", content: "잠깐 멈추니 마음이 조금 가벼워졌다.", createdAt: .now.addingTimeInterval(-Double(i * 300)), emotion: emotion))
        }
        let (window, host) = try makeHost(IPadWorkspaceView(recordStore: store))
        defer { close(window) }
        try await capture(window, host, "01-home-landscape")

        var moment = RecordDraft(title: "바람을 따라 걷던 오후", content: "오늘은 조금 천천히 걸었다.\n늘 지나던 길을 벗어나 바다 쪽으로 발걸음을 옮겼다.\n\n바람은 생각보다 차가웠고, 마음은 생각보다 가벼웠다.", emotion: "평온")
        moment.attachPhoto(photo(), at: "오늘은 조금 천천히 걸었다.\n늘 지나던 길을 벗어나 바다 쪽으로 발걸음을 옮겼다.\n\n".utf16.count)
        host.rootView = themed(IPadMomentEditor(draft: moment, recordStore: store))
        try await capture(window, host, "02-moment-landscape")
        window.frame.size = CGSize(width: 600, height: 834)
        try await capture(window, host, "03-moment-narrow")

        window.frame.size = CGSize(width: 1194, height: 834)
        host.rootView = themed(IPadJournalEditor(draft: IPadDraftPreparation.journal(on: JournalDay(date: .now), store: store), recordStore: store))
        try await capture(window, host, "04-journal-landscape")
        window.frame.size = CGSize(width: 834, height: 1194)
        try await capture(window, host, "05-journal-portrait")

        let archive = RecordStore(isStoredInMemoryOnly: true)
        let day = JournalDay(date: .now)
        let journal = try #require(archive.saveJournal(on: day, title: "바람을 따라 걷던 하루", body: moment.content, sourceRecordIDs: [], emotion: "평온", document: moment.diaryDocument))
        let archiveState = IPadArchiveNavigation()
        archiveState.day = day
        archiveState.selection = .journal(journal.id)
        window.frame.size = CGSize(width: 1194, height: 834)
        host.rootView = themed(IPadArchiveView(recordStore: archive, navigation: archiveState, onEdit: { _ in }))
        try await capture(window, host, "06-archive-landscape")
        let searchState = IPadSearchNavigation()
        searchState.query = "바람"
        searchState.selection = .journal(journal.id)
        host.rootView = themed(IPadSearchView(recordStore: archive, navigation: searchState, onEdit: { _ in }))
        try await capture(window, host, "07-search-landscape")
        host.rootView = themed(IPadMomentEditor(draft: moment, recordStore: store).environment(\.dynamicTypeSize, .accessibility3))
        window.frame.size = CGSize(width: 600, height: 834)
        try await capture(window, host, "08-moment-accessibility")
        host.rootView = themed(IPadWorkspaceView(recordStore: store))
        window.frame.size = CGSize(width: 834, height: 1194)
        try await capture(window, host, "09-home-portrait")
        window.frame.size = CGSize(width: 600, height: 834)
        try await capture(window, host, "10-home-narrow")
        host.rootView = themed(IPadMomentEditor(draft: RecordDraft(), recordStore: store))
        window.frame.size = CGSize(width: 834, height: 1194)
        try await capture(window, host, "11-emotion-portrait")
    }

    private func makeHost<V: View>(_ root: V) throws -> (UIWindow, UIHostingController<AnyView>) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
        window.overrideUserInterfaceStyle = .light
        let host = UIHostingController(rootView: themed(root))
        window.rootViewController = host
        window.isHidden = false
        return (window, host)
    }
    private func themed<V: View>(_ view: V) -> AnyView {
        AnyView(view.environment(\.locale, Locale(identifier: "ko_KR")).tint(Color.whisperAccent))
    }
    private func close(_ window: UIWindow) { window.isHidden = true; window.rootViewController = nil }
    private func settle() async throws { try await Task.sleep(for: .milliseconds(500)) }
    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }
    private func capture(_ window: UIWindow, _ host: UIHostingController<AnyView>, _ name: String) async throws {
        try await settle()
        window.endEditing(true)
        try await settle()
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(path: "IPadUICaptures")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let url = output.appending(path: "\(name).png")
        try #require(image.pngData()).write(to: url)
        print("IPAD_UI_CAPTURE \(url.path)")
    }
    private func photo() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            UIColor.systemBlue.withAlphaComponent(0.3).setFill(); context.fill(CGRect(x: 0, y: 180, width: 400, height: 120))
        }
    }
}
