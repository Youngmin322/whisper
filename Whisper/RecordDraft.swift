//
//  RecordDraft.swift
//  Whisper
//

import Foundation

struct RecordDraft {
    var title = ""
    var content = ""

    var titleForSaving: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "오늘의 마음" : trimmedTitle
    }

    var contentForSaving: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSave: Bool {
        !contentForSaving.isEmpty
    }
}
