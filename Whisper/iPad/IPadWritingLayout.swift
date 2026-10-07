import SwiftUI

enum IPadWritingLayout {
    static let paperWidth: CGFloat = 660
    static let contextWidth: CGFloat = 280

    static func showsContext(width: CGFloat, dynamicTypeSize: DynamicTypeSize) -> Bool {
        width >= 900 && !dynamicTypeSize.isAccessibilitySize
    }
}

struct IPadPaper<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(WhisperSpacing.xxLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.whisperSurfaceDefault, in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: WhisperRadius.medium)
                    .stroke(Color.whisperBorderSubtle, lineWidth: 1)
            }
            .frame(maxWidth: IPadWritingLayout.paperWidth)
    }
}

enum IPadDraftPreparation {
    static func journal(on day: JournalDay, store: RecordStore) -> JournalWritingDraft {
        let existing = store.journal(on: day)
        let value = store.writingDraftStore.journalDraft(on: day, existingJournalID: existing?.id)
            ?? JournalWritingDraft(day: day, existing: existing, records: existing == nil ? store.uncollectedMoments(on: day) : [])
        return journal(value, store: store)
    }

    static func journal(_ draft: JournalWritingDraft, store: RecordStore) -> JournalWritingDraft {
        let existing = store.journals.first { $0.id == draft.existingJournalID }
        let moments = store.uncollectedMoments(on: draft.day)
        return store.prepareJournalDraft(draft, existing: existing)
            .includingNewMoments(from: moments, documents: Dictionary(uniqueKeysWithValues:
                moments.map { ($0.id, store.diaryDocument(for: $0)) }))
    }

    static func moment(_ record: WhisperRecord, store: RecordStore) -> RecordDraft {
        store.writingDraftStore.momentEditDraft(for: record.id)
            ?? RecordDraft(title: record.title, content: record.content, emotion: record.emotion,
                           photoData: record.photoData, document: store.diaryDocument(for: record),
                           existingRecordID: record.id)
    }
}

struct IPadEmotionChoices: View {
    @Binding var emotion: String?
    var isSidebar = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if isSidebar { ScrollView { choices } }
            else { choices }
        }
        .background(Color.whisperSurfaceFocus)
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.large) {
            Text("지금 내 마음은 어떤가요?")
                .font(.whisperHandwriting(28))
            Text("가장 가까운 감정 하나를 골라보세요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: WhisperSpacing.small),
                                     count: isSidebar || dynamicTypeSize.isAccessibilitySize ? 2 : 3), spacing: WhisperSpacing.small) {
                ForEach(WhisperEmotion.selectableCases) { value in
                    Button { emotion = value.rawValue } label: {
                        VStack(spacing: WhisperSpacing.xSmall) {
                            FlameCharacter(emotion: value.rawValue, size: 53)
                                .frame(height: 64)
                                .accessibilityHidden(true)
                            Text(value.rawValue).font(.whisperControl)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 154 : 129)
                        .background(emotion == value.rawValue ? Color.whisperSurfaceHighlight : Color.whisperSurfaceDefault,
                                    in: RoundedRectangle(cornerRadius: WhisperRadius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: WhisperRadius.medium)
                                .stroke(Color.whisperBorderSubtle, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(value.rawValue)
                    .accessibilityAddTraits(emotion == value.rawValue ? .isSelected : [])
                    .accessibilityIdentifier("record.emotion.\(value.id)")
                }
            }
        }
        .padding(WhisperSpacing.large)
        .foregroundStyle(Color.whisperTextPrimary)
    }
}
