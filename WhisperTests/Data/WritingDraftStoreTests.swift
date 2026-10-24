import Foundation
import SwiftData
import Testing
@testable import Whisper

@MainActor
@Suite("작성 초안의 저장·복구", .serialized)
struct WritingDraftStoreTests {
    private enum SaveFailure: Error { case unavailable }

    @Test("읽을 수 없는 초안이 있어도 정상 순간·수정·일기를 복구하고 원본 행을 보존한다",
          arguments: ["moment", "edit", "journal"], ["malformed", "incompatible"])
    func restoresHealthyDraftsBesideUnreadableRows(kind: String, payloadKind: String) throws {
        let schema = Schema(versionedSchema: WhisperSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let initial = WritingDraftStore(context: context)
        var moment = RecordDraft(content: "정상 순간", emotion: "기쁨")
        moment.setDiaryDocument(.moment(text: moment.content, photoData: Data([1, 2, 3])))
        let edit = RecordDraft(content: "정상 수정", emotion: "평온", existingRecordID: UUID())
        var journal = JournalWritingDraft(day: day("2026-10-24"), existing: nil, records: [])
        journal.body = "정상 일기"
        journal.document = .moment(text: journal.body, photoData: Data([4, 5, 6]))
        #expect(initial.save(moment))
        #expect(initial.save(edit))
        #expect(initial.save(journal))

        let id = UUID()
        let key = kind == "journal" ? "journal:new:2026-10-23"
            : "moment:\(kind == "edit" ? "edit" : "new"):\(id.uuidString)"
        let payload = Data((payloadKind == "malformed" ? "broken-json" : "{}").utf8)
        let photo = Data(repeating: 0xA5, count: 200_000)
        let damaged = WritingDraft(id: id, storageKey: key, payload: payload, photoData: photo)
        damaged.updatedAt = .distantFuture
        context.insert(damaged)
        try context.save()

        let reopened = WritingDraftStore(context: context)
        #expect(reopened.momentDrafts == [moment])
        #expect(reopened.momentEditDrafts == [edit])
        #expect(reopened.journalDrafts == [journal])
        #expect(reopened.unreadableDrafts.map(\.id) == [id])
        #expect(reopened.count == 4)
        #expect(reopened.errorMessage == nil)
        reopened.retry()
        moment.content = "정상 초안은 계속 수정할 수 있다"
        #expect(reopened.save(moment))
        #expect(reopened.momentDraft?.content == moment.content)
        let preserved = try #require(context.fetch(FetchDescriptor<WritingDraft>()).first { $0.id == id })
        #expect(preserved.storageKey == key)
        #expect(preserved.payload == payload)
        #expect(preserved.photoData == photo)
        #expect(preserved.updatedAt == .distantFuture)
    }

    @Test("모든 초안이 읽기 불가여도 목록 진입을 유지하고 다시 읽을 수 있게 되면 복구한다")
    func tracksAllUnreadableRowsAndRetriesAfterRepair() throws {
        let schema = Schema(versionedSchema: WhisperSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let repaired = RecordDraft(content: "다시 읽을 수 있는 순간", emotion: "기쁨")
        let row = WritingDraft(id: repaired.id, storageKey: repaired.storageKey, payload: Data("broken-json".utf8))
        let future = WritingDraft(id: UUID(), storageKey: "future:kind", payload: Data([9]), photoData: Data([8]))
        context.insert(row)
        context.insert(future)
        try context.save()

        let store = WritingDraftStore(context: context)
        #expect(store.count == 2)
        #expect(store.momentDrafts.isEmpty)
        #expect(Set(store.unreadableDrafts.map(\.id)) == [row.id, future.id])
        store.retry()
        #expect(store.unreadableDrafts.count == 2)

        // Simulate a later decoder-compatible payload without deleting its row.
        row.payload = try JSONEncoder().encode(repaired)
        try context.save()
        store.retry()
        #expect(store.momentDrafts == [repaired])
        #expect(store.unreadableDrafts.map(\.id) == [future.id])
        #expect(store.count == 2)
        #expect(future.payload == Data([9]) && future.photoData == Data([8]))
    }

    @Test("정상 초안을 확정 저장한 뒤 저장소를 다시 열어도 읽기 불가 원본과 사진은 남는다")
    func publishingHealthyDraftPreservesUnreadableRowAcrossReopen() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        let damagedID = UUID()
        let payload = Data("not-json".utf8)
        let photo = Data(repeating: 0xAB, count: 200_000)
        let draft = RecordDraft(content: "정상 순간은 저장할 수 있다", emotion: "기쁨")
        do {
            let schema = Schema(versionedSchema: WhisperSchemaV7.self)
            let container = try ModelContainer(for: schema, migrationPlan: WhisperMigrationPlan.self,
                                               configurations: configuration)
            container.mainContext.insert(WritingDraft(id: damagedID, storageKey: "journal:new:2026-10-23",
                                                      payload: payload, photoData: photo))
            try container.mainContext.save()
        }
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.isPersistenceAvailable)
            #expect(store.saveMomentDraft(draft)?.id == draft.id)
            #expect(store.writingDraftStore.momentDrafts.isEmpty)
            #expect(store.writingDraftStore.unreadableDrafts.map(\.id) == [damagedID])
        }
        let schema = Schema(versionedSchema: WhisperSchemaV7.self)
        let reopened = try ModelContainer(for: schema, migrationPlan: WhisperMigrationPlan.self,
                                          configurations: configuration)
        let rows = try reopened.mainContext.fetch(FetchDescriptor<WritingDraft>())
        #expect(rows.count == 1)
        #expect(rows.first?.id == damagedID)
        #expect(rows.first?.payload == payload)
        #expect(rows.first?.photoData == photo)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<WhisperRecord>()).map(\.id) == [draft.id])
    }

    @Test("같은 날짜의 새 일기는 읽을 수 없는 초안 원본을 덮어쓰지 않는다")
    func doesNotOverwriteUnreadableJournalWithSameStorageKey() throws {
        let schema = Schema(versionedSchema: WhisperSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        var newDraft = JournalWritingDraft(day: day("2026-10-24"), existing: nil, records: [])
        newDraft.body = "새로 작성한 일기"
        let id = UUID()
        let payload = Data("broken-json".utf8)
        let photo = Data([7, 8, 9])
        context.insert(WritingDraft(id: id, storageKey: newDraft.storageKey, payload: payload, photoData: photo))
        try context.save()
        let store = WritingDraftStore(context: context)
        #expect(!store.save(newDraft))
        #expect(store.journalDrafts == [newDraft])
        #expect(store.errorMessage != nil)
        let preserved = try #require(context.fetch(FetchDescriptor<WritingDraft>()).first)
        #expect(preserved.id == id)
        #expect(preserved.payload == payload && preserved.photoData == photo)
        store.retry()
        #expect(preserved.payload == payload && preserved.photoData == photo)
    }

    @Test("읽을 수 없는 다른 행이 있어도 저장 실패한 최신 순간을 유지하고 재시도한다")
    func preservesPendingEditsAlongsideUnreadableRows() throws {
        let schema = Schema(versionedSchema: WhisperSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        var shouldFail = false
        let store = WritingDraftStore(context: context) { context in
            if shouldFail { throw SaveFailure.unavailable }
            try context.save()
        }
        var draft = RecordDraft(content: "기존 내용", emotion: "기쁨")
        #expect(store.save(draft))
        let damaged = WritingDraft(id: UUID(), storageKey: "journal:new:2026-10-23", payload: Data([0]))
        context.insert(damaged)
        try context.save()
        store.reload()
        shouldFail = true
        draft.content = "저장 실패 후에도 남아야 하는 내용"
        draft.photoData = Data([3, 2, 1])
        #expect(!store.save(draft))
        #expect(store.momentDraft == draft)
        #expect(store.unreadableDrafts.map(\.id) == [damaged.id])
        #expect(store.errorMessage != nil)
        shouldFail = false
        store.retry()
        let reopened = WritingDraftStore(context: context)
        #expect(reopened.momentDraft == draft)
        #expect(reopened.unreadableDrafts.map(\.id) == [damaged.id])
        #expect(store.errorMessage == nil)
    }

    @Test("완성하지 않은 순간과 첨부 완료 사진을 새 저장소 인스턴스에서 복구한다", arguments: ["emotion", "text", "photo", "all"])
    func restoresIncompleteMoment(kind: String) throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        var draft = RecordDraft()
        if kind == "emotion" || kind == "all" { draft.emotion = "기쁨" }
        if kind == "text" || kind == "all" { draft.content = "  쓰다 멈춘 문장\n"; draft.title = "  내 제목  " }
        if kind == "photo" || kind == "all" { draft.photoData = Data(repeating: 0xA5, count: 200_000) }
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.save(draft))
            #expect(store.records.isEmpty)
            #expect(store.journals.isEmpty)
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.isPersistenceAvailable)
        #expect(reopened.writingDraftStore.momentDraft == draft)
        #expect(reopened.writingDraftStore.count == 1)
        #expect(reopened.records.isEmpty)
    }

    @Test("날짜별 새 일기와 기존 일기 수정 초안을 원본과 분리해 복구한다")
    func restoresSeparateJournalsAndFrozenDay() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        let firstDay = day("2026-09-30", zone: "Asia/Seoul")
        let nextDay = day("2026-10-01", zone: "Asia/Seoul")
        let otherDay = day("2026-10-02", zone: "America/Los_Angeles")
        var snapshots: [JournalWritingDraft] = []
        var journalID: UUID!
        var recordID: UUID!
        do {
            let store = RecordStore(configuration: configuration)
            let record = try #require(store.addAndReturn(title: "원문", content: "수정되지 않을 순간",
                                                       createdAt: firstDay.date.addingTimeInterval(3600), emotion: "평온"))
            recordID = record.id
            let existing = try #require(store.saveJournal(on: firstDay, title: "원래 제목", body: "원래 일기",
                                                         sourceRecordIDs: [record.id], emotion: "평온"))
            journalID = existing.id
            var edited = JournalWritingDraft(day: firstDay, existing: existing, records: store.records)
            edited.title = "수정 중 제목"
            edited.body = "수정 중 본문"
            edited.representativeEmotion = "슬픔"
            var next = JournalWritingDraft(day: nextDay, existing: nil, records: [])
            next.body = "자정 전에 쓰기 시작한 일기"
            next.representativeEmotion = "설렘"
            var other = JournalWritingDraft(day: otherDay, existing: nil, records: [])
            other.title = "다른 날짜의 제목"
            snapshots = [edited, next, other]
            for snapshot in snapshots { #expect(store.writingDraftStore.save(snapshot)) }
            #expect(store.journals.count == 1)
            #expect(store.journals.first?.body == "원래 일기")
            #expect(store.record(withID: record.id)?.content == "수정되지 않을 순간")
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.writingDraftStore.journalDrafts.count == 3)
        for snapshot in snapshots {
            #expect(reopened.writingDraftStore.journalDrafts.first { $0.id == snapshot.id } == snapshot)
        }
        let edited = try #require(reopened.writingDraftStore.journalDraft(on: firstDay, existingJournalID: journalID))
        #expect(edited.sourceRecordIDs == [recordID!])
        let saved = try #require(reopened.saveJournalDraft(snapshots[1]))
        #expect(saved.dayKey == "2026-10-01")
        #expect(saved.date == nextDay.date)
        #expect(saved.body == snapshots[1].body)
        #expect(saved.emotion == "설렘")
        #expect(reopened.journals.first { $0.id == journalID }?.body == "원래 일기")
        #expect(reopened.writingDraftStore.journalDrafts.count == 2)
    }

    @Test("초안에 일기를 작성하거나 버려도 홈 순간과 기존 일기는 바뀌지 않는다")
    func discardOnlyRemovesDraft() throws {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let targetDay = day("2026-10-01")
        let photo = Data([1, 2, 3])
        let record = try #require(store.addAndReturn(title: "원본", content: "원본 본문",
                                                   createdAt: targetDay.date.addingTimeInterval(3600), photoData: photo))
        var newDraft = JournalWritingDraft(day: targetDay, existing: nil, records: store.records)
        newDraft.body = "초안에서 고친 문장"
        #expect(store.writingDraftStore.save(newDraft))
        #expect(store.uncollectedMoments(on: targetDay).map(\.id) == [record.id])
        #expect(store.writingDraftStore.discard(id: newDraft.id))
        #expect(store.journals.isEmpty)

        let existing = try #require(store.saveJournal(on: targetDay, title: "기존 제목", body: "기존 일기",
                                                      sourceRecordIDs: [record.id], emotion: "평온"))
        var edit = JournalWritingDraft(day: targetDay, existing: existing, records: store.records)
        edit.body = "저장하지 않은 수정"
        edit.representativeEmotion = "기쁨"
        #expect(store.writingDraftStore.save(edit))
        #expect(store.writingDraftStore.discard(id: edit.id))
        #expect(store.refreshPersistentState())
        #expect(store.journals.first?.body == "기존 일기")
        #expect(store.journals.first?.emotion == "평온")
        #expect(store.record(withID: record.id)?.photoData == photo)
        #expect(store.record(withID: record.id)?.content == "원본 본문")
        #expect(store.writingDraftStore.count == 0)
    }

    @Test("완성한 순간의 저장과 초안 삭제가 함께 유지되고 재시도해도 기록은 하나다")
    func finalMomentSaveClearsDraftWithoutDuplicates() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        let draft = RecordDraft(title: "순간 제목", content: "완성한 문장", emotion: "기쁨", photoData: Data([3, 4]))
        do {
            let store = RecordStore(configuration: configuration)
            #expect(store.writingDraftStore.save(draft))
            #expect(store.saveMomentDraft(draft)?.id == draft.id)
            #expect(store.writingDraftStore.momentDraft == nil)
            #expect(store.saveMomentDraft(draft)?.id == draft.id)
            #expect(store.records.count == 1)
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.writingDraftStore.count == 0)
        #expect(reopened.records.count == 1)
        #expect(reopened.records.first?.photoData == draft.photoData)
    }

    @Test("기존 일기 최종 저장은 UUID와 회고를 보존하고 수정 초안만 지운다")
    func finalJournalEditClearsDraft() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        var journalID: UUID!
        do {
            let store = RecordStore(configuration: configuration)
            let targetDay = day("2026-10-01")
            let journal = try #require(store.saveJournal(on: targetDay, title: "원래 제목", body: "원래 내용",
                                                        sourceRecordIDs: [], emotion: "평온"))
            journal.reflection = "원래 회고"
            journalID = journal.id
            var draft = JournalWritingDraft(day: targetDay, existing: journal, records: [])
            draft.title = "새 제목"
            draft.body = "새 내용"
            draft.representativeEmotion = "기쁨"
            #expect(store.writingDraftStore.save(draft))
            #expect(store.saveJournalDraft(draft)?.id == journalID)
            #expect(store.writingDraftStore.count == 0)
            #expect(store.saveJournalDraft(draft)?.id == journalID)
            #expect(store.journals.count == 1)
        }
        let reopened = RecordStore(configuration: configuration)
        #expect(reopened.journals.first?.id == journalID)
        #expect(reopened.journals.first?.body == "새 내용")
        #expect(reopened.journals.first?.emotion == "기쁨")
        #expect(reopened.journals.first?.reflection == "원래 회고")
        #expect(reopened.writingDraftStore.count == 0)
    }

    @Test("임시 저장 실패는 최신 내용을 메모리에 남기고 재시도로 기기에 저장한다")
    func autosaveFailureRetainsMemoryAndRetries() throws {
        let schema = Schema(versionedSchema: WhisperSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        var shouldFail = false
        let drafts = WritingDraftStore(context: container.mainContext) { context in
            if shouldFail { throw SaveFailure.unavailable }
            try context.save()
        }
        var draft = RecordDraft(content: "마지막으로 저장된 내용", emotion: "기쁨")
        #expect(drafts.save(draft))
        shouldFail = true
        draft.content = "실패해도 잃으면 안 되는 최신 내용"
        draft.photoData = Data([5, 6, 7])
        #expect(!drafts.save(draft))
        #expect(drafts.errorMessage != nil)
        #expect(drafts.momentDraft == draft)
        drafts.reload()
        #expect(drafts.momentDraft == draft)
        #expect(drafts.errorMessage != nil)
        let persisted = WritingDraftStore(context: container.mainContext)
        #expect(persisted.momentDraft?.content == "마지막으로 저장된 내용")
        shouldFail = false
        drafts.retry()
        #expect(drafts.errorMessage == nil)
        #expect(WritingDraftStore(context: container.mainContext).momentDraft == draft)
    }

    @Test("최종 저장 실패는 기록 생성과 초안 삭제를 롤백하고 재시도 시 하나만 저장한다", arguments: ["moment", "journal", "edit"])
    func recordSaveFailureRollsBackDraftDeletion(kind: String) throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = configuration(at: directory)
        var saveAttempt = 0
        var failAtAttempt: Int?
        let store = RecordStore(configuration: configuration) { context in
            saveAttempt += 1
            if saveAttempt == failAtAttempt { throw SaveFailure.unavailable }
            try context.save()
        }
        if kind == "moment" {
            let draft = RecordDraft(content: "잃지 않을 순간", emotion: "기쁨")
            #expect(store.writingDraftStore.save(draft))
            failAtAttempt = saveAttempt + 2 // Flush succeeds; publishing the record fails.
            #expect(store.saveMomentDraft(draft) == nil)
            #expect(store.records.isEmpty)
            #expect(store.writingDraftStore.momentDraft == draft)
            #expect(RecordStore(configuration: configuration).writingDraftStore.momentDraft == draft)
            failAtAttempt = nil
            #expect(store.saveMomentDraft(draft) != nil)
            #expect(store.saveMomentDraft(draft) != nil)
            #expect(store.records.count == 1)
        } else {
            let targetDay = day("2026-10-01")
            let existing = kind == "edit" ? store.saveJournal(on: targetDay, title: "원본", body: "원본 일기",
                                                              sourceRecordIDs: [], emotion: "평온") : nil
            var draft = JournalWritingDraft(day: targetDay, existing: existing, records: [])
            draft.body = "보관해야 하는 새 내용"
            draft.representativeEmotion = "기쁨"
            #expect(store.writingDraftStore.save(draft))
            failAtAttempt = saveAttempt + 2
            #expect(store.saveJournalDraft(draft) == nil)
            #expect(store.journals.count == (kind == "edit" ? 1 : 0))
            if kind == "edit" { #expect(store.journals.first?.body == "원본 일기") }
            #expect(store.writingDraftStore.journalDrafts == [draft])
            #expect(RecordStore(configuration: configuration).writingDraftStore.journalDrafts == [draft])
            failAtAttempt = nil
            #expect(store.saveJournalDraft(draft) != nil)
            #expect(store.saveJournalDraft(draft) != nil)
            #expect(store.journals.count == 1)
        }
        #expect(store.writingDraftStore.count == 0)
        #expect(RecordStore(configuration: configuration).writingDraftStore.count == 0)
    }

    @Test("복구 후 추가된 순간만 한 번 붙이고 수동 본문과 대표 감정을 보존한다")
    func mergesNewMomentsOnce() {
        let targetDay = day("2026-10-01")
        let first = WhisperRecord(title: "첫째", content: "첫 문장", createdAt: targetDay.date.addingTimeInterval(3600), emotion: "평온")
        let second = WhisperRecord(title: "둘째", content: "새 문장", createdAt: targetDay.date.addingTimeInterval(7200), emotion: "기쁨")
        let tomorrow = WhisperRecord(title: "다음 날", content: "다른 날짜", createdAt: targetDay.nextBoundary.addingTimeInterval(3600))
        var draft = JournalWritingDraft(day: targetDay, existing: nil, records: [first])
        draft.body = "수동으로 고친 본문"
        draft.representativeEmotion = "슬픔"
        let resumed = draft.includingNewMoments(from: [first, second, tomorrow])
        #expect(resumed.body == "수동으로 고친 본문\n\n새 문장")
        #expect(resumed.sourceRecordIDs == [first.id, second.id])
        #expect(resumed.representativeEmotion == "슬픔")
        #expect(resumed.includingNewMoments(from: [first, second, tomorrow]) == resumed)
    }

    @Test("입력을 모두 지우면 빈 순간 초안은 남기지 않는다")
    func emptyMomentClearsSavedDraft() {
        let store = RecordStore(isStoredInMemoryOnly: true)
        var draft = RecordDraft(content: "지울 내용", emotion: "기쁨")
        #expect(store.writingDraftStore.save(draft))
        draft.content = ""
        draft.emotion = nil
        #expect(store.writingDraftStore.save(draft))
        #expect(store.writingDraftStore.momentDraft == nil)
        #expect(store.writingDraftStore.count == 0)
    }

    @Test("V5 저장소를 V6로 옮겨도 기록·일기·사진을 보존하고 초안을 저장할 수 있다")
    func migratesV5Store() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recordID = UUID()
        let journalID = UUID()
        let targetDay = day("2026-10-01")
        let photo = Data(repeating: 0x7F, count: 200_000)
        do {
            let schema = Schema(versionedSchema: WhisperSchemaV5.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(
                schema: schema, url: directory.appending(path: "default.store"), cloudKitDatabase: .none))
            container.mainContext.insert(WhisperRecord(id: recordID, title: "이전 순간", content: "원본",
                                                     createdAt: targetDay.date, emotion: "평온", photoData: photo))
            container.mainContext.insert(DailyJournal(id: journalID, dayKey: targetDay.key, date: targetDay.date,
                                                     title: "이전 일기", body: "일기 원문", reflection: "회고",
                                                     emotion: "슬픔", sourceRecordIDs: [recordID]))
            try container.mainContext.save()
        }
        let store = RecordStore(configuration: configuration(at: directory))
        #expect(store.isPersistenceAvailable)
        #expect(store.records.map(\.id) == [recordID])
        #expect(store.records.first?.photoData == photo)
        #expect(store.journals.map(\.id) == [journalID])
        #expect(store.journals.first?.reflection == "회고")
        #expect(store.journals.first?.emotion == "슬픔")
        #expect(store.journals.first?.sourceRecordIDs == [recordID])
        #expect(store.writingDraftStore.count == 0)
        #expect(store.writingDraftStore.save(RecordDraft(content: "새 초안")))
    }

    private func day(_ key: String, zone: String = "Asia/Seoul") -> JournalDay {
        let calendar = JournalDayKey.calendar(timeZone: TimeZone(identifier: zone)!)
        return JournalDay(date: JournalDayKey.date(for: key, timeZone: calendar.timeZone)!, calendar: calendar)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "WhisperDraftTests-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func configuration(at directory: URL) -> ModelConfiguration {
        ModelConfiguration(schema: Schema(versionedSchema: WhisperSchemaV7.self),
                           url: directory.appending(path: "default.store"), cloudKitDatabase: .none)
    }
}
