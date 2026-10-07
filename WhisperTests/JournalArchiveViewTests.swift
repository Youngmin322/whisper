import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("보관함 편집 화면의 순간 추가", .serialized)
struct JournalArchiveViewTests {
    @Test("시간대가 바뀐 편집 화면에서도 다른 일기에 담긴 원본을 중복해서 가져오지 않는다")
    func editorExcludesMomentsAlreadyCollectedOnAnotherCivilDay() async throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let seoulCalendar = JournalDayKey.calendar(timeZone: TimeZone(identifier: "Asia/Seoul")!)
        let seoul = JournalDay(date: JournalDayKey.date(for: "2026-10-01", timeZone: seoulCalendar.timeZone)!, calendar: seoulCalendar)
        let laCalendar = JournalDayKey.calendar(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        let laDay = JournalDay(date: JournalDayKey.date(for: "2026-09-30", timeZone: laCalendar.timeZone)!, calendar: laCalendar)
        let collected = try #require(store.addAndReturn(title: "원본", content: "이미 담은 순간", createdAt: seoul.date))
        _ = try #require(store.saveJournal(on: seoul, title: "서울 일기", body: collected.content, sourceRecordIDs: [collected.id]))
        let newMoment = try #require(store.addAndReturn(title: "새 순간", content: "새로 담을 순간", createdAt: laDay.date.addingTimeInterval(3600)))
        let (window, _) = try makeHost(NavigationStack { JournalEditorView(day: laDay, recordStore: store) })
        defer { window.isHidden = true; window.rootViewController = nil }
        try await settle()
        let draft = try #require(store.writingDraftStore.journalDrafts.first)
        #expect(draft.body == newMoment.content)
        #expect(draft.sourceRecordIDs == [newMoment.id])
        #expect(draft.day == laDay)
    }

    private func makeHost<V: View>(_ root: V) throws -> (UIWindow, UIHostingController<AnyView>) {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let host = UIHostingController(rootView: AnyView(root))
        window.rootViewController = host
        window.isHidden = false
        return (window, host)
    }

    private func settle() async throws { try await Task.sleep(for: .milliseconds(250)) }
}
