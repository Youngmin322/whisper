import SwiftUI

struct JournalSearchHighlightedText: View {
    let text: String
    let query: String

    var highlighted: AttributedString {
        var value = AttributedString(text)
        var cursor = text.startIndex
        while cursor < text.endIndex,
              let range = JournalSearchSnippet.range(of: query, in: text, within: cursor..<text.endIndex) {
            if let lower = AttributedString.Index(range.lowerBound, within: value),
               let upper = AttributedString.Index(range.upperBound, within: value) {
                value[lower..<upper].foregroundColor = Color.whisperTextPrimary
                value[lower..<upper].backgroundColor = Color.whisperAccent.opacity(0.22)
                value[lower..<upper].font = Font.whisperDiaryBody.weight(.semibold)
            }
            cursor = range.upperBound
        }
        return value
    }

    var body: some View {
        Text(highlighted).font(.whisperDiaryBody)
    }
}

struct JournalSearchMatchPreview: View {
    let result: JournalArchiveSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let context = result.searchContext,
               let description = context.description(for: result.kind) {
                Text(description)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperAccentText)
            }
            JournalSearchHighlightedText(text: result.preview, query: result.searchContext?.query ?? "")
                .foregroundStyle(Color.whisperTextSecondary)
                .lineLimit(3)
        }
    }
}
