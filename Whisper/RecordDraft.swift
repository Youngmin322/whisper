//
//  RecordDraft.swift
//  Whisper
//

import Foundation

enum RecordWritingCopy {
    static let titleLabel = String(localized: "제목 · 선택 사항")
    static let titleExample = String(localized: "예: 집에 돌아오던 길")
    static let titleHelp = String(localized: "나중에 이 순간을 알아볼 수 있는 짧은 이름이면 충분해요.")
    static let contentLabel = String(localized: "남기고 싶은 순간")
    static let contentExample = String(localized: "기억하고 싶은 일을 적어보세요.")
}

struct RecordDraft: Codable, Equatable, Identifiable {
    static let contentLimit = 1_000

    var id = UUID()
    var title = ""
    var content = ""
    var emotion: String?
    var photoData: Data?
    var document: DiaryDocument? = nil
    var existingRecordID: UUID? = nil

    var storageKey: String {
        existingRecordID.map { "moment:edit:\($0.uuidString)" } ?? "moment:new:\(id.uuidString)"
    }

    var titleForSaving: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? String(localized: "오늘의 마음") : trimmedTitle
    }

    var contentForSaving: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !contentForSaving.isEmpty && content.count <= Self.contentLimit
    }

    var canSaveNewMoment: Bool {
        emotion != nil && canSave
    }

    var hasChanges: Bool {
        existingRecordID != nil || !title.isEmpty || !content.isEmpty || emotion != nil || photoData != nil
    }
}
