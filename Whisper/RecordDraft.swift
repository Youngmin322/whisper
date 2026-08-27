//
//  RecordDraft.swift
//  Whisper
//

import Foundation

enum RecordWritingCopy {
    static let titleLabel = "이 마음에 이름을 붙인다면? (선택)"
    static let titleExample = "예: 조급해하지 않기로 한 저녁"
    static let titleHelp = "나중에 다시 봤을 때 이 순간이 떠오르는 짧은 문장이 좋아요."
    static let contentLabel = "지금 마음에 남은 장면은 무엇인가요?"
    static let contentExample = "예: 발표를 마치고 나니 다음에도 해볼 수 있겠다는 마음이 들었다."
}

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
