import SwiftUI

struct JournalMemorySearchView: View {
    let recordStore: RecordStore

    @State private var query = ""

    var body: some View {
        let index = JournalArchiveIndex(records: recordStore.records, journals: recordStore.journals)
        let results = index.results(matching: query)
        Group {
            if index.days.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "아직 남긴 기록이 없어요"), systemImage: "calendar")
                } description: {
                    Text(String(localized: "일기와 아직 담지 않은 순간을 제목·내용·감정으로 찾을 수 있어요."))
                }
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(results) { result in
                    NavigationLink {
                        switch result.kind {
                        case .journal:
                            JournalDetailView(journalID: result.recordID, recordStore: recordStore,
                                              searchContext: result.searchContext)
                        case .moment:
                            if let record = recordStore.record(withID: result.recordID) {
                                RecordDetailView(record: record, recordStore: recordStore)
                            } else {
                                ContentUnavailableView(String(localized: "순간을 찾을 수 없어요"), systemImage: "flame")
                            }
                        }
                    } label: {
                        JournalSearchResultRow(result: result)
                    }
                    .listRowBackground(Color.whisperBackground)
                    .listRowSeparatorTint(Color.whisperDivider)
                    .accessibilityIdentifier("archive.search.\(result.id)")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.whisperBackground.ignoresSafeArea())
        .navigationTitle(String(localized: "기억 찾기"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: "일기와 순간에서 검색"))
        .textInputAutocapitalization(.never)
    }

}

private struct JournalSearchResultRow: View {
    let result: JournalArchiveSearchResult

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Group {
                if result.kind == .journal { FlameBottle(emotion: result.emotion, width: 42) }
                else { FlameCharacter(emotion: result.emotion, size: 38) }
            }
            .frame(width: 44).accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("\(result.day.fullDescription) · \(result.kind.label)")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperAccentText)

                Text(result.title)
                    .font(.whisperHandwriting(22))
                    .foregroundStyle(Color.whisperTextPrimary)
                    .lineLimit(1)

                JournalSearchMatchPreview(result: result)
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.day.fullDescription), \(result.kind.label), \(result.title), \(result.searchContext?.description(for: result.kind) ?? ""), \(result.preview)")
    }
}
