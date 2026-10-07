import SwiftUI
import Observation

@Observable
final class IPadArchiveNavigation {
    var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    var day: JournalDay?
    var selection: IPadEntry?
    var path: [IPadEntry] = []
}

@Observable
final class IPadSearchNavigation {
    var query = ""
    var selection: IPadEntry?
    var path: [IPadEntry] = []
}

struct IPadArchiveView: View {
    let recordStore: RecordStore
    @Bindable var navigation: IPadArchiveNavigation
    let onEdit: (IPadEditorSession) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var index: JournalArchiveIndex {
        JournalArchiveIndex(records: recordStore.records, journals: recordStore.journals)
    }

    var body: some View {
        GeometryReader { geometry in
            let showsReader = geometry.size.width >= 850 && !dynamicTypeSize.isAccessibilitySize
            NavigationStack(path: $navigation.path) {
                HStack(spacing: 0) {
                    archiveList(showsReader: showsReader)
                        .frame(maxWidth: showsReader ? 320 : .infinity)
                    if showsReader {
                        Divider()
                        reader
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationTitle("보관함")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: IPadEntry.self) { entry in
                    IPadEntryReader(entry: entry, recordStore: recordStore, onEdit: onEdit, onDelete: clearSelection)
                }
                .onChange(of: showsReader, initial: true) { _, wide in
                    if wide { navigation.path = [] }
                    else if let selection = navigation.selection { navigation.path = [selection] }
                }
            }
        }
        .background(Color.whisperBackground)
    }

    private func archiveList(showsReader: Bool) -> some View {
        List {
            Section {
                IPadCalendar(month: $navigation.month, selectedDay: navigation.day, index: index, onSelect: { day in
                    navigation.day = day
                    navigation.selection = nil
                    navigation.path = []
                })
                .listRowInsets(EdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12))
                .listRowSeparator(.hidden)
            }
            if let day = navigation.day, let entry = index.entry(for: day.key) {
                Section(day.fullDescription) {
                    ForEach(entry.journals) { journal in
                        entryButton(.journal(journal.id), showsReader: showsReader) {
                            IPadArchiveRow(title: journal.title.isEmpty ? "이날의 하루" : journal.title,
                                           preview: journal.body, emotion: journal.emotion, isJournal: true,
                                           metadata: "담긴 순간 \(journal.sourceRecordIDs.count)개")
                        }
                    }
                    ForEach(entry.uncollectedMoments) { moment in
                        entryButton(.moment(moment.id), showsReader: showsReader) {
                            IPadArchiveRow(title: moment.title, preview: moment.content, emotion: moment.emotion,
                                           isJournal: false, metadata: moment.createdAt.whisperDateTimeDescription)
                        }
                    }
                    if entry.canCollect {
                        Button(entry.collectionTitle) {
                            onEdit(.journal(IPadDraftPreparation.journal(on: day, store: recordStore)))
                        }
                        .font(.whisperControl)
                        .accessibilityIdentifier("archive.collectButton")
                    }
                }
            } else {
                Section {
                    Text(navigation.day == nil ? "날짜를 골라 그날의 기록을 펼쳐보세요." : "이날의 기록이 없어요.")
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .padding(.vertical, WhisperSpacing.large)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listRowBackground(Color.whisperSurfaceFocus)
        .background(showsReader ? Color.whisperSurfaceFocus : Color.whisperBackground)
        .accessibilityIdentifier("ipad.archive.list")
    }

    @ViewBuilder
    private func entryButton<Content: View>(_ entry: IPadEntry, showsReader: Bool, @ViewBuilder content: () -> Content) -> some View {
        Button {
            navigation.selection = entry
            if !showsReader { navigation.path.append(entry) }
        } label: { content() }
        .buttonStyle(.plain)
        .listRowBackground(navigation.selection == entry ? Color.whisperSurfaceHighlight : Color.clear)
        .accessibilityAddTraits(navigation.selection == entry ? .isSelected : [])
        .accessibilityIdentifier("ipad.archive.\(entry.id)")
    }

    @ViewBuilder
    private var reader: some View {
        if let entry = navigation.selection {
            IPadEntryReader(entry: entry, recordStore: recordStore, onEdit: onEdit, onDelete: clearSelection, presentsNavigationTitle: false)
                .id(entry)
        } else {
            IPadEmptyState(title: navigation.day == nil ? "날짜를 골라보세요" : "읽을 기록을 선택해 주세요")
            .accessibilityIdentifier("ipad.archive.emptySelection")
        }
    }

    private func clearSelection() {
        navigation.selection = nil
        navigation.path = []
    }
}

struct IPadSearchView: View {
    let recordStore: RecordStore
    @Bindable var navigation: IPadSearchNavigation
    let onEdit: (IPadEditorSession) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var results: [JournalArchiveSearchResult] {
        JournalArchiveIndex(records: recordStore.records, journals: recordStore.journals).results(matching: navigation.query)
    }

    var body: some View {
        GeometryReader { geometry in
            let showsReader = geometry.size.width >= 850 && !dynamicTypeSize.isAccessibilitySize
            NavigationStack(path: $navigation.path) {
                HStack(spacing: 0) {
                    resultList(showsReader: showsReader)
                        .frame(maxWidth: showsReader ? 320 : .infinity)
                    if showsReader {
                        Divider()
                        Group {
                            if let entry = navigation.selection {
                                IPadEntryReader(entry: entry, recordStore: recordStore, onEdit: onEdit, onDelete: clearSelection, presentsNavigationTitle: false)
                                    .id(entry)
                            } else {
                                IPadEmptyState(title: "읽을 기록을 선택해 주세요")
                                .accessibilityIdentifier("ipad.search.emptySelection")
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationTitle("기억 찾기")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $navigation.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "일기와 순간에서 검색")
                .textInputAutocapitalization(.never)
                .navigationDestination(for: IPadEntry.self) { entry in
                    IPadEntryReader(entry: entry, recordStore: recordStore, onEdit: onEdit, onDelete: clearSelection)
                }
                .onChange(of: showsReader, initial: true) { _, wide in
                    if wide { navigation.path = [] }
                    else if let selection = navigation.selection { navigation.path = [selection] }
                }
                .onChange(of: navigation.query) { _, _ in
                    if let selected = navigation.selection, !results.contains(where: { self.entry(for: $0) == selected }) {
                        clearSelection()
                    }
                }
            }
        }
        .background(Color.whisperBackground)
    }

    @ViewBuilder
    private func resultList(showsReader: Bool) -> some View {
        if results.isEmpty {
            IPadEmptyState(title: navigation.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                           ? "어떤 기억을 찾고 있나요?" : "찾는 기록이 없어요",
                           message: navigation.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                           ? "기억나는 말을 적어보세요" : "다른 말로 찾아보세요")
        } else {
            List(results) { result in
                Button {
                    navigation.selection = entry(for: result)
                    if !showsReader { navigation.path.append(entry(for: result)) }
                } label: {
                    IPadArchiveRow(title: result.title, preview: result.preview, emotion: result.emotion,
                                   isJournal: result.kind == .journal, metadata: "\(result.day.fullDescription) · \(result.kind.label)")
                }
                .buttonStyle(.plain)
                .listRowBackground(navigation.selection == entry(for: result) ? Color.whisperSurfaceHighlight : Color.clear)
                .accessibilityAddTraits(navigation.selection == entry(for: result) ? .isSelected : [])
                .accessibilityIdentifier("archive.search.\(result.id)")
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(showsReader ? Color.whisperSurfaceFocus : Color.whisperBackground)
            .accessibilityIdentifier("ipad.search.results")
        }
    }

    private func entry(for result: JournalArchiveSearchResult) -> IPadEntry {
        result.kind == .journal ? .journal(result.recordID) : .moment(result.recordID)
    }

    private func clearSelection() {
        navigation.selection = nil
        navigation.path = []
    }
}

private struct IPadArchiveRow: View {
    let title: String
    let preview: String
    let emotion: String?
    let isJournal: Bool
    let metadata: String

    var body: some View {
        HStack(alignment: .top, spacing: WhisperSpacing.small) {
            Group {
                if isJournal { FlameBottle(emotion: emotion, width: 28) }
                else { FlameCharacter(emotion: emotion, size: 28) }
            }
            .frame(width: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                Text(metadata).font(.whisperMetadata).foregroundStyle(Color.whisperTextSecondary)
                Text(title.isEmpty ? "남겨둔 순간" : title).font(.whisperHandwriting(22)).lineLimit(2)
                Text(preview).font(.whisperDiaryBody).lineLimit(2).foregroundStyle(Color.whisperTextSecondary)
            }
        }
        .foregroundStyle(Color.whisperTextPrimary)
        .padding(.vertical, WhisperSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct IPadCalendar: View {
    @Binding var month: Date
    let selectedDay: JournalDay?
    let index: JournalArchiveIndex
    let onSelect: (JournalDay) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private var calendar: Calendar {
        var value = JournalDayKey.calendar(timeZone: .current)
        value.firstWeekday = 2
        return value
    }
    private var dates: [Date?] {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start,
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.map { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
    }

    var body: some View {
        VStack(spacing: WhisperSpacing.large) {
            HStack {
                monthButton("chevron.left", label: "이전 달", offset: -1)
                Spacer(minLength: 0)
                Text(month.formatted(Date.FormatStyle(calendar: calendar).locale(Locale(identifier: "ko_KR")).year().month()))
                    .font(.whisperHandwriting(25))
                Spacer(minLength: 0)
                monthButton("chevron.right", label: "다음 달", offset: 1)
            }
            LazyVGrid(columns: columns, spacing: WhisperSpacing.xSmall) {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { day in
                    Text(day).font(.whisperCaption).foregroundStyle(Color.whisperTextSecondary)
                }
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    if let date { cell(date) }
                    else { Color.clear.frame(height: 64).accessibilityHidden(true) }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: WhisperSpacing.small) { legend }
                VStack(alignment: .leading, spacing: WhisperSpacing.small) { legend }
            }
            .font(.whisperCaption).foregroundStyle(Color.whisperTextSecondary)
        }
    }

    @ViewBuilder private var legend: some View {
        HStack(spacing: 5) { FlameBottle(emotion: nil, width: 13); Text("담긴 하루") }
        HStack(spacing: 5) { FlameCharacter(emotion: "기쁨", size: 18); Text("미보관 순간") }
    }

    private func cell(_ date: Date) -> some View {
        let day = JournalDay(date: date, calendar: calendar)
        let entry = index.entry(for: day.key)
        return Button { onSelect(day) } label: {
            VStack(spacing: WhisperSpacing.xxSmall) {
                Text("\(calendar.component(.day, from: date))").font(.whisperCaption)
                HStack(spacing: 0) {
                    if let journal = entry?.journals.first { FlameBottle(emotion: journal.emotion, width: 19) }
                    if let moment = entry?.uncollectedMoments.last { FlameCharacter(emotion: moment.emotion, size: 19) }
                }
                .frame(height: 29)
                .accessibilityHidden(true)
            }
            .foregroundStyle(Color.whisperTextPrimary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(selectedDay?.key == day.key ? Color.whisperSurfaceHighlight : Color.clear,
                        in: RoundedRectangle(cornerRadius: WhisperRadius.small))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(entry == nil)
        .accessibilityLabel(entry?.accessibilityDescription ?? "\(day.fullDescription), 기록 없음")
        .accessibilityAddTraits(selectedDay?.key == day.key ? .isSelected : [])
        .accessibilityIdentifier("archive.day.\(day.key)")
    }

    private func monthButton(_ symbol: String, label: String, offset: Int) -> some View {
        Button {
            if let next = calendar.date(byAdding: .month, value: offset, to: month) { month = next }
        } label: { Image(systemName: symbol).frame(width: 44, height: 44) }
        .accessibilityLabel(label)
    }
}
