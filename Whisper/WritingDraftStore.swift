import Foundation
import Observation
import SwiftData

/// Shares the record context so publishing a record and removing its draft are atomic.
@MainActor
@Observable
final class WritingDraftStore {
    private(set) var momentDraft: RecordDraft?
    private(set) var journalDrafts: [JournalWritingDraft] = []
    private(set) var errorMessage: String?
    @ObservationIgnored private let context: ModelContext?
    // A disappearing editor may outlive its parent store for one render pass.
    @ObservationIgnored private let modelContainer: ModelContainer?
    @ObservationIgnored private let persist: (ModelContext) throws -> Void
    @ObservationIgnored private var rows: [WritingDraft] = []
    @ObservationIgnored private var pendingMoment: RecordDraft?
    @ObservationIgnored private var pendingJournals: [String: JournalWritingDraft] = [:]

    init(context: ModelContext?, persist: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        modelContainer = context?.container
        self.persist = persist
        reload()
    }

    var count: Int { (momentDraft?.hasChanges == true ? 1 : 0) + journalDrafts.count }

    func journalDraft(on day: JournalDay, existingJournalID: UUID?) -> JournalWritingDraft? {
        let key = existingJournalID.map { "journal:edit:\($0.uuidString)" } ?? "journal:new:\(day.key)"
        return journalDrafts.first { $0.storageKey == key }
    }

    @discardableResult
    func save(_ draft: RecordDraft) -> Bool {
        pendingMoment = draft
        momentDraft = draft
        var text = draft
        text.photoData = nil
        return write {
            if draft.hasChanges {
                try upsert(id: draft.id, key: "moment", payload: JSONEncoder().encode(text), photoData: draft.photoData)
            } else {
                stageCompletion(of: draft.id)
            }
        } onSuccess: {
            pendingMoment = nil
        }
    }

    @discardableResult
    func save(_ draft: JournalWritingDraft) -> Bool {
        pendingJournals[draft.storageKey] = draft
        journalDrafts.removeAll { $0.storageKey == draft.storageKey }
        journalDrafts.append(draft)
        return write {
            try upsert(id: draft.id, key: draft.storageKey, payload: JSONEncoder().encode(draft), photoData: nil)
        } onSuccess: {
            pendingJournals.removeValue(forKey: draft.storageKey)
        }
    }

    @discardableResult
    func discard(id: UUID) -> Bool {
        write { stageCompletion(of: id) } onSuccess: { clearPending(id: id) }
    }

    func retry() {
        let moment = pendingMoment
        let journals = Array(pendingJournals.values)
        if moment == nil && journals.isEmpty { reload(); return }
        if let moment, !save(moment) { return }
        for journal in journals {
            if !save(journal) { return }
        }
    }

    /// Called before the record context's save; rollback restores this row on failure.
    func stageCompletion(of id: UUID) {
        guard let context else { return }
        for row in rows where row.id == id { context.delete(row) }
    }

    func didComplete(id: UUID) {
        clearPending(id: id)
        if momentDraft?.id == id { momentDraft = nil }
        journalDrafts.removeAll { $0.id == id }
        reload()
    }

    func reload() {
        guard let context else {
            errorMessage = "초안을 보관할 저장소를 사용할 수 없어요."
            return
        }
        do {
            rows = try context.fetch(FetchDescriptor<WritingDraft>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
            var moment: RecordDraft?
            var journals: [JournalWritingDraft] = []
            for row in rows {
                if row.storageKey == "moment" {
                    var decoded = try JSONDecoder().decode(RecordDraft.self, from: row.payload)
                    decoded.photoData = row.photoData
                    moment = decoded
                } else {
                    journals.append(try JSONDecoder().decode(JournalWritingDraft.self, from: row.payload))
                }
            }
            momentDraft = pendingMoment ?? moment
            let keys = Set(pendingJournals.keys)
            journalDrafts = journals.filter { !keys.contains($0.storageKey) }
                + pendingJournals.values.sorted { $0.day.key > $1.day.key }
            if pendingMoment == nil && pendingJournals.isEmpty { errorMessage = nil }
        } catch {
            errorMessage = "보관한 초안을 불러오지 못했어요. 현재 작성 내용은 화면에 남아 있어요."
        }
    }

    private func upsert(id: UUID, key: String, payload: Data, photoData: Data?) throws {
        guard let context else { return }
        if let row = rows.first(where: { $0.storageKey == key }) {
            row.id = id
            row.payload = payload
            if row.photoData != photoData { row.photoData = photoData }
            row.updatedAt = .now
        } else {
            context.insert(WritingDraft(id: id, storageKey: key, payload: payload, photoData: photoData))
        }
    }

    private func write(_ change: () throws -> Void, onSuccess: () -> Void) -> Bool {
        guard let context else {
            errorMessage = "초안을 보관할 저장소를 사용할 수 없어요."
            return false
        }
        do {
            try change()
            try persist(context)
            onSuccess()
            reload()
            return true
        } catch {
            context.rollback()
            reload()
            errorMessage = "초안을 임시 저장하지 못했어요. 앱을 닫기 전에 다시 시도해 주세요."
            return false
        }
    }

    private func clearPending(id: UUID) {
        if pendingMoment?.id == id { pendingMoment = nil }
        pendingJournals = pendingJournals.filter { $0.value.id != id }
    }
}
