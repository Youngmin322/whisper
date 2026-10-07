import SwiftUI

struct JournalArchiveDayView: View {
    let day: JournalDay
    let recordStore: RecordStore

    var body: some View {
        let entry = JournalArchiveIndex(records: recordStore.records, journals: recordStore.journals,
                                        calendar: day.calendar).entry(for: day.key)
        ScrollView {
            VStack(alignment: .leading, spacing: WhisperSpacing.xLarge) {
                Text(day.fullDescription)
                    .font(.whisperHandwriting(24, bold: true))
                    .foregroundStyle(Color.whisperTextPrimary)

                if let entry {
                    if entry.hasJournal {
                        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
                            Text("담긴 하루").font(.whisperSectionTitle)
                            ForEach(entry.journals) { journal in
                                NavigationLink {
                                    JournalDetailView(journalID: journal.id, recordStore: recordStore)
                                } label: {
                                    journalRow(journal)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("archive.journalButton")
                            }
                        }
                    }
                    if entry.hasUncollectedMoments {
                        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
                            Text("아직 담지 않은 순간 · \(entry.uncollectedMoments.count)개")
                                .font(.whisperSectionTitle)
                            ForEach(entry.uncollectedMoments) { moment in
                                NavigationLink {
                                    RecordDetailView(record: moment, recordStore: recordStore)
                                } label: {
                                    momentRow(moment)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("archive.momentButton")
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("이날의 기록이 없어요", systemImage: "calendar")
                }
            }
            .foregroundStyle(Color.whisperTextPrimary)
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.vertical, WhisperSpacing.large)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color.whisperBackground)
        .navigationTitle("날짜별 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if let entry, entry.hasUncollectedMoments {
                NavigationLink {
                    JournalEditorView(day: day, recordStore: recordStore, existing: entry.journals.first)
                } label: {
                    Text(entry.collectionTitle)
                }
                .buttonStyle(.whisperPrimary)
                .disabled(!entry.canCollect)
                .accessibilityIdentifier("archive.collectButton")
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.vertical, WhisperSpacing.small)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .background(Color.whisperBackground)
            }
        }
    }

    private func journalRow(_ journal: DailyJournal) -> some View {
        HStack(spacing: WhisperSpacing.medium) {
            FlameBottle(emotion: journal.emotion, width: 42)
            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                Text(journal.title.isEmpty ? "이날의 하루" : journal.title)
                    .font(.whisperHandwriting(22, bold: true))
                    .lineLimit(2)
                Text(journal.body).font(.whisperBody).lineLimit(3)
                    .foregroundStyle(Color.whisperTextSecondary)
                Text("담긴 순간 \(journal.sourceRecordIDs.count)개")
                    .font(.whisperMetadata).foregroundStyle(Color.whisperTextSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.whisperTextSecondary)
        }
        .padding(WhisperSpacing.medium)
        .whisperCardStyle(fill: .whisperSurfaceDefault, border: .whisperBorderSubtle)
        .accessibilityElement(children: .combine)
    }

    private func momentRow(_ moment: WhisperRecord) -> some View {
        HStack(spacing: WhisperSpacing.medium) {
            FlameCharacter(emotion: moment.emotion, size: 38).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                HStack(spacing: WhisperSpacing.small) {
                    Text(moment.createdAt.formatted(Date.FormatStyle(
                        locale: Locale(identifier: "ko_KR"), calendar: day.calendar,
                        timeZone: day.calendar.timeZone).hour().minute()))
                    if let emotion = moment.emotion { Text(emotion) }
                    if moment.photoData != nil { Image(systemName: "photo").accessibilityLabel("사진 있음") }
                }
                .font(.whisperMetadata).foregroundStyle(Color.whisperTextSecondary)
                Text(moment.title.isEmpty ? "남겨둔 순간" : moment.title).font(.whisperControl).lineLimit(1)
                Text(moment.content).font(.whisperBody).lineLimit(2).foregroundStyle(Color.whisperTextSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.whisperTextSecondary)
        }
        .padding(WhisperSpacing.medium)
        .whisperCardStyle(fill: .whisperSurfaceDefault, border: .whisperBorderSubtle)
        .accessibilityElement(children: .combine)
    }
}
