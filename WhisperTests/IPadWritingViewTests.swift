import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("iPad 작성과 창 크기 변경", .serialized)
struct IPadWritingViewTests {
    @Test("순간의 네이티브 입력과 사진 위치는 창을 줄여도 유지되며 초안으로 다시 열린다")
    func momentSurvivesResizeAndReopen() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        var initial = RecordDraft(title: "바람을 따라 걷던 오후", content: "오늘 👨‍👩‍👧\n기억할 순간", emotion: "평온")
        initial.attachPhoto(photo(), at: "오늘 👨‍👩‍👧\n".utf16.count)
        let (window, host) = try makeHost(IPadMomentEditor(draft: initial, recordStore: store))
        defer { close(window) }
        try await settle()
        let editor = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "record.contentField" })
        #expect(editor.accessibilityLabel == (Bundle.main.preferredLocalizations.first == "en" ? "Moment text" : "순간 본문"))
        let inserted = "처음의 마음\n"
        editor.textStorage.insert(NSAttributedString(string: inserted, attributes: DiaryTextFormatter.attributes(font: .systemFont(ofSize: 18))), at: 0)
        editor.delegate?.textViewDidChange?(editor)
        try await settle()
        let beforeResize = try #require(store.writingDraftStore.momentDraft)
        #expect(beforeResize.content == inserted + initial.content)
        #expect(beforeResize.diaryDocument.photos.first?.offset == initial.diaryDocument.photos[0].offset + inserted.utf16.count)

        window.frame.size = CGSize(width: 600, height: 834)
        try await settle()
        let resized = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "record.contentField" })
        #expect(resized === editor)
        #expect(store.writingDraftStore.momentDraft == beforeResize)
        #expect(DiaryTextFormatter.document(from: resized.attributedText).photos.first?.data == initial.photoData)

        host.rootView = AnyView(EmptyView())
        try await settle()
        #expect(store.refreshPersistentState())
        let restored = try #require(store.writingDraftStore.momentDraft)
        host.rootView = AnyView(IPadMomentEditor(draft: restored, recordStore: store))
        try await settle()
        #expect(textViews(in: host.view).contains { $0.accessibilityIdentifier == "record.contentField" && $0.attributedText.string.contains(inserted) })
        #expect(store.records.isEmpty)
    }

    @Test("일기 편집은 원본을 유지하며 사진이 포함된 수정 초안을 세로·좁은 창에서도 복원한다")
    func journalKeepsSourcesAndDraftAcrossLayouts() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let source = try #require(store.addAndReturn(title: "바다", content: "오후의 바다\n바람이 좋았다.", emotion: "평온", photoData: photo()))
        let day = JournalDay(date: source.createdAt)
        let initial = IPadDraftPreparation.journal(on: day, store: store)
        let journal = try #require(store.saveJournalDraft(initial))
        let draft = IPadDraftPreparation.journal(on: day, store: store)
        let (window, host) = try makeHost(IPadJournalEditor(draft: draft, recordStore: store))
        defer { close(window) }
        try await settle()
        let editor = try #require(textViews(in: host.view).first { $0.accessibilityIdentifier == "journal.bodyField" })
        #expect(editor.accessibilityLabel == (Bundle.main.preferredLocalizations.first == "en" ? "Journal entry text" : "일기 본문"))
        editor.textStorage.append(NSAttributedString(string: "\n집에 돌아와 다시 떠올렸다.", attributes: DiaryTextFormatter.attributes(font: .systemFont(ofSize: 18))))
        editor.delegate?.textViewDidChange?(editor)
        try await settle()
        let saved = try #require(store.writingDraftStore.journalDrafts.first)
        #expect(saved.body.contains("다시 떠올렸다"))
        #expect(saved.sourceRecordIDs == [source.id])
        #expect(saved.document?.photos.first?.data == source.photoData)
        #expect(journal.body == initial.body)
        #expect(source.content == "오후의 바다\n바람이 좋았다.")

        for size in [CGSize(width: 834, height: 1194), CGSize(width: 600, height: 834)] {
            window.frame.size = size
            try await settle()
            #expect(textViews(in: host.view).first { $0.accessibilityIdentifier == "journal.bodyField" } === editor)
            #expect(store.writingDraftStore.journalDrafts.first == saved)
        }
        host.rootView = AnyView(EmptyView())
        try await settle()
        #expect(store.refreshPersistentState())
        let restored = try #require(store.writingDraftStore.journalDrafts.first)
        host.rootView = AnyView(IPadJournalEditor(draft: restored, recordStore: store))
        try await settle()
        #expect(textViews(in: host.view).contains { $0.attributedText.string.contains("다시 떠올렸다") })
        #expect(store.journals.count == 1)
    }

    @Test("이미 다른 일기에 담긴 순간은 시간대가 바뀌어도 iPad 초안에 중복되지 않는다")
    func preparationUsesUncollectedMoments() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let seoul = JournalDay(date: .now, calendar: JournalDayKey.calendar(timeZone: TimeZone(identifier: "Asia/Seoul")!))
        let record = try #require(store.addAndReturn(title: "원본", content: "이미 담은 순간", createdAt: seoul.date))
        _ = try #require(store.saveJournal(on: seoul, title: "하루", body: record.content, sourceRecordIDs: [record.id]))
        let la = JournalDay(date: record.createdAt, calendar: JournalDayKey.calendar(timeZone: TimeZone(identifier: "America/Los_Angeles")!))
        let draft = IPadDraftPreparation.journal(on: la, store: store)
        if la.key != seoul.key {
            #expect(draft.sourceRecordIDs.isEmpty)
            #expect(draft.body.isEmpty)
        }
    }

    private func makeHost<V: View>(_ root: V) throws -> (UIWindow, UIHostingController<AnyView>) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
        let host = UIHostingController(rootView: AnyView(root.environment(\.locale, Locale(identifier: "ko_KR"))))
        window.rootViewController = host
        window.isHidden = false
        return (window, host)
    }
    private func close(_ window: UIWindow) { window.isHidden = true; window.rootViewController = nil }
    private func settle() async throws { try await Task.sleep(for: .milliseconds(300)) }
    private func textViews(in view: UIView) -> [UITextView] {
        (view as? UITextView).map { [$0] } ?? view.subviews.flatMap { textViews(in: $0) }
    }
    private func photo() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60)).jpegData(withCompressionQuality: 0.9) { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }
    }
}
