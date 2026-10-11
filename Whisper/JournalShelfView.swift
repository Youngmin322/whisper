import SwiftUI

struct JournalShelfView: View {
    let recordStore: RecordStore

    @State private var displayedMonth = JournalCalendar.calendar.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDay: JournalDay?
    @State private var isDayPresented = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0, alignment: .top), count: 7)

    var body: some View {
        let index = JournalArchiveIndex(records: recordStore.records, journals: recordStore.journals,
                                        calendar: JournalCalendar.calendar)
        let monthEntries = index.days.filter {
            JournalCalendar.calendar.isDate($0.day.date, equalTo: displayedMonth, toGranularity: .month)
        }
        ScrollView {
            VStack(spacing: 22) {
                monthHeader
                weekdayHeader
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(JournalCalendar.days(in: displayedMonth)) { day in
                        calendarCell(for: day, index: index)
                    }
                }
                .padding(.horizontal, 16)
                calendarLegend
                archiveSummary(entries: monthEntries).padding(.top, 8)
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(Color.whisperBackground.ignoresSafeArea())
        .navigationTitle("보관함")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    JournalMemorySearchView(recordStore: recordStore)
                } label: {
                    Image(systemName: "magnifyingglass").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("기억 찾기")
                .accessibilityIdentifier("archive.searchButton")
            }
        }
        .navigationDestination(isPresented: $isDayPresented) {
            if let selectedDay { JournalArchiveDayView(day: selectedDay, recordStore: recordStore) }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 12) {
            monthButton(systemName: "chevron.left", accessibilityLabel: "이전 달") { changeMonth(by: -1) }
            Spacer(minLength: 8)
            VStack(spacing: 1) {
                Text(displayedMonth.formatted(JournalCalendar.yearStyle))
                    .font(.whisperHandwriting(18)).foregroundStyle(Color.whisperTextSecondary)
                Text(displayedMonth.formatted(JournalCalendar.monthStyle))
                    .font(.whisperHandwriting(34)).foregroundStyle(Color.whisperTextPrimary)
                    .contentTransition(.numericText())
                    .background(alignment: .bottom) {
                        Capsule().fill(Color.whisperSurfaceHighlight).frame(height: 8).offset(y: -2)
                    }
            }
            Spacer(minLength: 8)
            monthButton(systemName: "chevron.right", accessibilityLabel: "다음 달") { changeMonth(by: 1) }
        }
        .padding(.horizontal, 16)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(JournalCalendar.weekdaySymbols, id: \.self) { symbol in
                Text(symbol).font(.whisperLabel).foregroundStyle(Color.whisperTextSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16).padding(.top, 4)
    }

    @ViewBuilder
    private func calendarCell(for day: JournalCalendarDay, index: JournalArchiveIndex) -> some View {
        if let date = day.date {
            let targetDay = JournalDay(date: date, calendar: JournalCalendar.calendar)
            let entry = index.entry(for: targetDay.key)
            Button {
                selectedDay = targetDay
                isDayPresented = true
            } label: {
                VStack(spacing: 3) {
                    Text(String(JournalCalendar.calendar.component(.day, from: date)))
                        .font(.whisperCaption)
                        .foregroundStyle(entry == nil ? Color.whisperTextSecondary : Color.whisperTextPrimary)
                        .frame(minHeight: 18)
                    Group {
                        if let entry {
                            HStack(alignment: .center, spacing: 0) {
                                if let journal = entry.journals.first {
                                    FlameBottle(emotion: journal.emotion, width: entry.hasUncollectedMoments ? 26 : 31)
                                }
                                if let moment = entry.uncollectedMoments.last {
                                    FlameCharacter(emotion: moment.emotion, size: entry.hasJournal ? 13 : 27)
                                }
                            }
                        } else {
                            Circle().fill(Color.whisperBorderSubtle.opacity(0.72)).frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 45, alignment: .top)
                    .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(entry == nil)
            .accessibilityLabel(entry?.accessibilityDescription ?? "\(targetDay.fullDescription), 기록 없음")
            .accessibilityHint(entry == nil ? "" : "두 번 탭하면 이날의 기록이 열려요")
            .accessibilityIdentifier("archive.day.\(targetDay.key)")
        } else {
            Color.clear.frame(height: 66).accessibilityHidden(true)
        }
    }

    private var calendarLegend: some View {
        HStack(spacing: 20) {
            HStack(spacing: 5) { FlameBottle(emotion: nil, width: 13); Text("담긴 하루") }
            HStack(spacing: 5) { FlameCharacter(emotion: "기쁨", size: 18); Text("미보관 순간") }
        }
        .font(.whisperCaption).foregroundStyle(Color.whisperTextSecondary)
        .accessibilityElement(children: .combine)
    }

    private func archiveSummary(entries: [JournalArchiveDay]) -> some View {
        let journalCount = entries.reduce(0) { $0 + $1.journals.count }
        let momentCount = entries.reduce(0) { $0 + $1.uncollectedMoments.count }
        return VStack(spacing: 8) {
            if entries.isEmpty {
                Text("이 달은 아직 비어 있어요").font(.whisperHandwriting(22))
                    .foregroundStyle(Color.whisperTextPrimary)
                Text("순간을 남기면 불꽃이, 일기로 담으면 병이 놓여요").font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
            } else {
                if journalCount > 0 {
                    Text("\(journalCount)개의 하루가 차곡차곡 담겼어요").font(.whisperHandwriting(21))
                }
                if momentCount > 0 { Text("아직 담지 않은 순간 \(momentCount)개").font(.whisperBody) }
            }
        }
        .foregroundStyle(Color.whisperTextSecondary)
        .multilineTextAlignment(.center).padding(.horizontal, 24)
    }

    private func monthButton(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.whisperTextSecondary).frame(width: 44, height: 44)
                .background(Color.whisperSurfaceDefault, in: Circle())
                .overlay { Circle().stroke(Color.whisperBorderSubtle, lineWidth: 1) }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func changeMonth(by offset: Int) {
        guard let next = JournalCalendar.calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { displayedMonth = next }
    }
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
    static var yearStyle: Date.FormatStyle {
        Date.FormatStyle(calendar: calendar).locale(Locale(identifier: "ko_KR")).year()
    }
    static var monthStyle: Date.FormatStyle {
        Date.FormatStyle(calendar: calendar).locale(Locale(identifier: "ko_KR")).month(.wide)
    }

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
