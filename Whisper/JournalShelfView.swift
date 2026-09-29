import SwiftUI

struct JournalShelfView: View {
    let recordStore: RecordStore

    @State private var displayedMonth = JournalCalendar.calendar.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var previewSelection: JournalPreviewSelection?
    @State private var pendingDetailJournalID: UUID?
    @State private var detailJournalID: UUID?
    @State private var isDetailPresented = false

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 0, alignment: .top),
        count: 7
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                monthHeader
                weekdayHeader

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(calendarDays) { day in
                        calendarCell(for: day)
                    }
                }
                .padding(.horizontal, 16)

                archiveSummary
                    .padding(.top, 8)
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(Color.whisperBackground.ignoresSafeArea())
        .navigationTitle("보관함")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    JournalMemorySearchView(recordStore: recordStore)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("기억 찾기")
            }
        }
        .sheet(item: $previewSelection, onDismiss: openPendingDetail) { selection in
            JournalPreviewSheet(
                journalID: selection.id,
                recordStore: recordStore,
                onOpen: {
                    pendingDetailJournalID = selection.id
                    previewSelection = nil
                }
            )
            .presentationDetents([.height(390), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(WhisperRadius.sheet)
            .presentationBackground(Color.whisperSurfaceDefault)
        }
        .navigationDestination(isPresented: $isDetailPresented) {
            if let detailJournalID {
                JournalDetailView(journalID: detailJournalID, recordStore: recordStore)
            }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 12) {
            monthButton(systemName: "chevron.left", accessibilityLabel: "이전 달") {
                changeMonth(by: -1)
            }

            Spacer(minLength: 8)

            VStack(spacing: 1) {
                Text(displayedMonth.formatted(JournalCalendar.yearStyle))
                    .font(.whisperHandwriting(18))
                    .foregroundStyle(Color.whisperTextSecondary)

                Text(displayedMonth.formatted(JournalCalendar.monthStyle))
                    .font(.whisperHandwriting(34, bold: true))
                    .foregroundStyle(Color.whisperTextPrimary)
                    .contentTransition(.numericText())
                    .background(alignment: .bottom) {
                        Capsule()
                            .fill(Color.whisperSurfaceHighlight)
                            .frame(height: 8)
                            .offset(y: -2)
                    }
            }

            Spacer(minLength: 8)

            monthButton(systemName: "chevron.right", accessibilityLabel: "다음 달") {
                changeMonth(by: 1)
            }
        }
        .padding(.horizontal, 16)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(JournalCalendar.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.whisperLabel)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func calendarCell(for day: JournalCalendarDay) -> some View {
        if let date = day.date {
            let journal = journal(on: date)

            Button {
                guard let journal else { return }
                previewSelection = JournalPreviewSelection(id: journal.id)
            } label: {
                VStack(spacing: 3) {
                    Text(dayNumber(for: date))
                        .font(.whisperCaption)
                        .foregroundStyle(journal == nil ? Color.whisperTextSecondary : Color.whisperTextPrimary)
                        .frame(minHeight: 18)

                    Group {
                        if let journal {
                            FlameBottle(emotion: journal.emotion, width: 31)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Circle()
                                .fill(Color.whisperBorderSubtle.opacity(0.72))
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 45, alignment: .top)
                }
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(journal == nil)
            .accessibilityLabel(accessibilityLabel(for: date, journal: journal))
            .accessibilityHint(journal == nil ? "" : "두 번 탭하면 일기 미리보기가 열려요")
        } else {
            Color.clear
                .frame(height: 66)
                .accessibilityHidden(true)
        }
    }

    private var archiveSummary: some View {
        VStack(spacing: 8) {
            if monthJournals.isEmpty {
                Text("이 달은 아직 비어 있어요")
                    .font(.whisperHandwriting(22, bold: true))
                    .foregroundStyle(Color.whisperTextPrimary)

                Text("하루를 마무리하면 달력에 작은 병이 놓여요")
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
            } else {
                Text("\(monthJournals.count)개의 하루가 차곡차곡 담겼어요")
                    .font(.whisperHandwriting(21))
                    .foregroundStyle(Color.whisperTextSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    private var monthJournals: [DailyJournal] {
        recordStore.journals.filter {
            JournalCalendar.calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month)
        }
    }

    private var calendarDays: [JournalCalendarDay] {
        JournalCalendar.days(in: displayedMonth)
    }

    private func journal(on date: Date) -> DailyJournal? {
        monthJournals.first { JournalCalendar.calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func dayNumber(for date: Date) -> String {
        String(JournalCalendar.calendar.component(.day, from: date))
    }

    private func accessibilityLabel(for date: Date, journal: DailyJournal?) -> String {
        guard let journal else { return "\(date.whisperFullDayDescription), 일기 없음" }
        let title = journal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty
            ? "\(date.whisperFullDayDescription), 일기 있음"
            : "\(date.whisperFullDayDescription), \(title)"
    }

    private func monthButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.whisperTextSecondary)
                .frame(width: 44, height: 44)
                .background(Color.whisperSurfaceDefault, in: Circle())
                .overlay {
                    Circle().stroke(Color.whisperBorderSubtle, lineWidth: 1)
                }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func changeMonth(by offset: Int) {
        guard let next = JournalCalendar.calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = next
        }
    }

    private func openPendingDetail() {
        guard let pendingDetailJournalID else { return }
        detailJournalID = pendingDetailJournalID
        self.pendingDetailJournalID = nil
        isDetailPresented = true
    }
}

private struct JournalPreviewSelection: Identifiable {
    let id: UUID
}

private struct JournalCalendarDay: Identifiable {
    let id: Int
    let date: Date?
}

private enum JournalCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        return calendar
    }

    static let weekdaySymbols = ["월", "화", "수", "목", "금", "토", "일"]
    static let yearStyle = Date.FormatStyle()
        .locale(Locale(identifier: "ko_KR"))
        .year()
    static let monthStyle = Date.FormatStyle()
        .locale(Locale(identifier: "ko_KR"))
        .month(.wide)

    static func days(in month: Date) -> [JournalCalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let occupiedCount = leadingEmptyCount + dayRange.count
        let trailingEmptyCount = (7 - occupiedCount % 7) % 7

        var result: [JournalCalendarDay] = []
        result.reserveCapacity(occupiedCount + trailingEmptyCount)

        for index in 0..<leadingEmptyCount {
            result.append(JournalCalendarDay(id: index, date: nil))
        }

        for dayOffset in 0..<dayRange.count {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthInterval.start)
            result.append(JournalCalendarDay(id: leadingEmptyCount + dayOffset, date: date))
        }

        for index in 0..<trailingEmptyCount {
            result.append(JournalCalendarDay(id: occupiedCount + index, date: nil))
        }

        return result
    }
}

private struct JournalPreviewSheet: View {
    let journalID: UUID
    let recordStore: RecordStore
    let onOpen: () -> Void

    var body: some View {
        Group {
            if let journal {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 18) {
                        FlameBottle(emotion: journal.emotion, width: 68)

                        VStack(alignment: .leading, spacing: 7) {
                            Text(journal.date.whisperFullDayDescription)
                                .font(.whisperMetadata)
                                .foregroundStyle(Color.whisperAccentText)

                            Text(displayTitle(for: journal))
                                .font(.whisperHandwriting(26, bold: true))
                                .foregroundStyle(Color.whisperTextPrimary)
                                .lineLimit(2)

                            Label("그날의 순간 \(journal.sourceRecordIDs.count)개", systemImage: "sparkles")
                                .font(.whisperCaption)
                                .foregroundStyle(Color.whisperTextSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(journal.body)
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextPrimary)
                        .lineSpacing(5)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 18)

                    Spacer(minLength: 18)

                    Button("이날의 일기 읽기", action: onOpen)
                        .buttonStyle(.whisperPrimary)
                }
                .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
                .padding(.top, 28)
                .padding(.bottom, 16)
            } else {
                ContentUnavailableView("일기를 찾을 수 없어요", systemImage: "book.closed")
            }
        }
        .background(Color.whisperSurfaceDefault)
    }

    private var journal: DailyJournal? {
        recordStore.journals.first { $0.id == journalID }
    }

    private func displayTitle(for journal: DailyJournal) -> String {
        let title = journal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "\(journal.date.whisperDayDescription)의 하루" : title
    }
}
