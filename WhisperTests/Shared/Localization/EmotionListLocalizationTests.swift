import SwiftUI
import Testing
import UIKit
import Vision
@testable import Whisper

@MainActor
@Suite("목록의 감정 표시 현지화", .serialized)
struct EmotionListLocalizationTests {
    private var isEnglish: Bool { WhisperLocalization.languageCode == "en" }

    @Test("날짜별 순간과 빈 본문 초안은 감정 표시 이름만 번역한다",
          arguments: ["기쁨", "차분함", "속상", ""], [false, true])
    func localizedEmotionRows(storedEmotion: String, isDraft: Bool) async throws {
        let emotion = storedEmotion.isEmpty ? nil : storedEmotion
        let store = RecordStore(isStoredInMemoryOnly: true)
        let title = "Stored title"
        let content = "Keep my words"
        let draft = RecordDraft(title: title, emotion: emotion)
        let day = JournalDay(date: .now)
        let root: AnyView
        if isDraft {
            #expect(store.writingDraftStore.save(draft))
            root = AnyView(WritingDraftListView(draftStore: store.writingDraftStore,
                                               onOpenMoment: { _ in }, onOpenJournal: { _ in }))
        } else {
            _ = try #require(store.addAndReturn(title: title, content: content, createdAt: day.date, emotion: emotion))
            root = AnyView(NavigationStack { JournalArchiveDayView(day: day, recordStore: store) })
        }
        let window = try makeHost(root)
        defer { close(window) }
        try await Task.sleep(for: .milliseconds(500))
        let text = try recognizedText(in: window)
        #expect(text.contains("storedtitle"))
        switch storedEmotion {
        case "기쁨": #expect(text.contains(isEnglish ? "joy" : "기쁨"))
        case "차분함": #expect(text.contains(isEnglish ? "calm" : "평온"))
        case "속상": #expect(text.contains(isEnglish ? "sadness" : "슬픔"))
        default:
            if isDraft { #expect(text.contains(isEnglish ? "continuewriting" : "이어서작성하기")) }
            else { #expect(!text.contains(isEnglish ? "joy" : "기쁨")) }
        }
        if isEnglish, !storedEmotion.isEmpty { #expect(!text.contains(storedEmotion)) }
        if isDraft {
            #expect(store.writingDraftStore.momentDraft == draft)
        } else {
            let record = try #require(store.records.first)
            #expect(record.emotion == emotion)
            #expect(record.title == title && record.content == content)
            #expect(text.contains("keepmywords"))
        }
    }

    @Test("본문이 있는 초안은 감정 이름 대신 사용자 원문을 표시한다")
    func draftContentTakesPrecedence() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let draft = RecordDraft(title: "Stored title", content: "Keep my words", emotion: "기쁨")
        #expect(store.writingDraftStore.save(draft))
        let window = try makeHost(WritingDraftListView(draftStore: store.writingDraftStore,
                                                       onOpenMoment: { _ in }, onOpenJournal: { _ in }))
        defer { close(window) }
        try await Task.sleep(for: .milliseconds(500))
        let text = try recognizedText(in: window)
        #expect(text.contains("storedtitle") && text.contains("keepmywords"))
        #expect(!text.contains(isEnglish ? "joy" : "기쁨"))
        #expect(store.writingDraftStore.momentDraft == draft)
    }

    private func makeHost<V: View>(_ root: V) throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 600, height: 1000)
        window.rootViewController = UIHostingController(rootView: root)
        window.makeKeyAndVisible()
        return window
    }

    private func close(_ window: UIWindow) {
        let scene = window.windowScene
        window.isHidden = true
        window.rootViewController = nil
        scene?.windows.first { !$0.isHidden }?.makeKey()
    }

    // Inspect the actual SwiftUI list rendering, including labels that are not UILabels.
    private func recognizedText(in window: UIWindow) throws -> String {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image {
            _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: #require(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().filter { !$0.isWhitespace }.lowercased()
    }
}
