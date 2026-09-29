import SwiftUI

struct JournalMemorySearchView: View {
    let recordStore: RecordStore

    @State private var query = ""

    var body: some View {
        Group {
            if recordStore.journals.isEmpty {
                ContentUnavailableView {
                    Label("아직 담긴 하루가 없어요", systemImage: "calendar")
                } description: {
                    Text("하루를 병에 담으면 제목과 내용으로 기억을 찾을 수 있어요.")
                }
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List(results) { journal in
                    NavigationLink {
                        JournalDetailView(journalID: journal.id, recordStore: recordStore)
                    } label: {
                        JournalSearchResultRow(journal: journal)
                    }
                    .listRowBackground(Color.whisperBackground)
                    .listRowSeparatorTint(Color.whisperDivider)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.whisperBackground.ignoresSafeArea())
        .navigationTitle("기억 찾기")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "일기와 순간에서 검색")
        .textInputAutocapitalization(.never)
    }

    private var results: [DailyJournal] {
        let sorted = recordStore.journals.sorted { $0.date > $1.date }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return sorted }

        return sorted.filter { journal in
            searchableTexts(for: journal).contains {
                $0.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
    }

    private func searchableTexts(for journal: DailyJournal) -> [String] {
        var texts = [journal.title, journal.body, journal.reflection, journal.emotion ?? ""]
        for id in journal.sourceRecordIDs {
            guard let record = recordStore.record(withID: id) else { continue }
            texts.append(record.title)
            texts.append(record.content)
        }
        return texts
    }
}

private struct JournalSearchResultRow: View {
    let journal: DailyJournal

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            FlameBottle(emotion: journal.emotion, width: 42)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(journal.date.whisperDateDescription)
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperAccentText)

                Text(displayTitle)
                    .font(.whisperHandwriting(22, bold: true))
                    .foregroundStyle(Color.whisperTextPrimary)
                    .lineLimit(1)

                Text(journal.body)
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(journal.date.whisperDateDescription), \(displayTitle), \(journal.body)")
    }

    private var displayTitle: String {
        let title = journal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "이날의 하루" : title
    }
}
