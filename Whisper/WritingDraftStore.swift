import Foundation
import Observation
import SwiftData

/// Shares the record context so publishing a record and removing its draft are atomic.
@MainActor
@Observable
final class WritingDraftStore {
    private(set) var momentDraft: RecordDraft?
    private(set) var momentEditDrafts: [RecordDraft] = []
    private(set) var journalDrafts: [JournalWritingDraft] = []
    private(set) var errorMessage: String?
    @ObservationIgnored private let context: ModelContext?
    // A disappearing editor may outlive its parent store for one render pass.
    @ObservationIgnored private let modelContainer: ModelContainer?
    @ObservationIgnored private let persist: (ModelContext) throws -> Void
    @ObservationIgnored private var rows: [WritingDraft] = []
    @ObservationIgnored private var pendingMoment: RecordDraft?
    @ObservationIgnored private var pendingMomentEdits: [String: RecordDraft] = [:]
    @ObservationIgnored private var pendingJournals: [String: JournalWritingDraft] = [:]

    init(context: ModelContext?, persist: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.context = context
        modelContainer = context?.container
        self.persist = persist
        reload()
    }

    var count: Int { (momentDraft?.hasChanges == true ? 1 : 0) + momentEditDrafts.count + journalDrafts.count }

    func momentEditDraft(for recordID: UUID) -> RecordDraft? {
        momentEditDrafts.first { $0.existingRecordID == recordID }
    }

    func journalDraft(on day: JournalDay, existingJournalID: UUID?) -> JournalWritingDraft? {
        let key = existingJournalID.map { "journal:edit:\($0.uuidString)" } ?? "journal:new:\(day.key)"
        return journalDrafts.first { $0.storageKey == key }
    }

    @discardableResult
    func save(_ draft: RecordDraft) -> Bool {
        if draft.existingRecordID == nil {
            pendingMoment = draft
            momentDraft = draft
        } else {
            pendingMomentEdits[draft.storageKey] = draft
            momentEditDrafts.removeAll { $0.storageKey == draft.storageKey }
            momentEditDrafts.append(draft)
        }
        var text = draft
        text.photoData = nil
        return write {
            if draft.hasChanges {
                try upsert(id: draft.id, key: draft.storageKey, payload: JSONEncoder().encode(text), photoData: draft.photoData)
            } else {
                stageCompletion(of: draft.id)
            }
        } onSuccess: {
            clearPending(id: draft.id)
        }
    }

    @discardableResult
    func save(_ draft: JournalWritingDraft) -> Bool {
        pendingJournals[draft.storageKey] = draft
        journalDrafts.removeAll { $0.storageKey == draft.storageKey }
        journalDrafts.append(draft)
        var metadata = draft
        metadata.document = draft.document?.withoutPhotoData
        return write {
            try upsert(id: draft.id, key: draft.storageKey, payload: JSONEncoder().encode(metadata),
                       photoData: draft.document.map { document in
                DiaryDocument(text: "", photos: document.photos.map { photo in
                    var snapshot = photo
                    snapshot.offset = 0
                    snapshot.caption = nil
                    snapshot.sourceRecordID = nil
                    return snapshot
                }).encoded()
            } ?? nil)
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
        let edits = Array(pendingMomentEdits.values)
        let journals = Array(pendingJournals.values)
        if moment == nil && edits.isEmpty && journals.isEmpty { reload(); return }
        if let moment, !save(moment) { return }
        for edit in edits {
            if !save(edit) { return }
        }
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
        momentEditDrafts.removeAll { $0.id == id }
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
            var edits: [RecordDraft] = []
            var journals: [JournalWritingDraft] = []
            for row in rows {
                if row.storageKey == "moment" || row.storageKey.hasPrefix("moment:edit:") {
                    var decoded = try JSONDecoder().decode(RecordDraft.self, from: row.payload)
                    decoded.photoData = row.photoData
                    if row.storageKey == "moment" { moment = decoded }
                    else { edits.append(decoded) }
                } else if row.storageKey.hasPrefix("journal:") {
                    var decoded = try JSONDecoder().decode(JournalWritingDraft.self, from: row.payload)
                    if let snapshot = DiaryDocument.decode(row.photoData) {
                        decoded.document = decoded.document?.restoringPhotos(from: snapshot)
                    }
                    journals.append(decoded)
                }
            }
            momentDraft = pendingMoment ?? moment
            let editKeys = Set(pendingMomentEdits.keys)
            momentEditDrafts = edits.filter { !editKeys.contains($0.storageKey) }
                + pendingMomentEdits.values.sorted { $0.id.uuidString < $1.id.uuidString }
            let keys = Set(pendingJournals.keys)
            journalDrafts = journals.filter { !keys.contains($0.storageKey) }
                + pendingJournals.values.sorted { $0.day.key > $1.day.key }
            if pendingMoment == nil && pendingMomentEdits.isEmpty && pendingJournals.isEmpty { errorMessage = nil }
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
        pendingMomentEdits = pendingMomentEdits.filter { $0.value.id != id }
        pendingJournals = pendingJournals.filter { $0.value.id != id }
    }
}
