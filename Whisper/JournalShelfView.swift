import SwiftUI

struct JournalShelfView: View {
    let recordStore: RecordStore

    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                monthHeader

                if monthJournals.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 90)
                        Text("이 달의 병은 아직 비어 있어요")
                            .font(.whisperHandwriting(24))
                            .foregroundStyle(Color.whisperTextPrimary)
                        Text("하루를 정리하면 여기에 한 병씩 놓여요")
                            .font(.whisperBody)
                            .foregroundStyle(Color.whisperTextSecondary)
                        Spacer(minLength: 100)
                    }
                } else {
                    VStack(spacing: 38) {
                        ForEach(rows.indices, id: \.self) { index in
                            shelfRow(rows[index])
                        }
                    }
                }

                Text("병을 열면 그날의 일기를 읽을 수 있어요")
                    .font(.whisperHandwriting(20))
                    .foregroundStyle(Color.whisperTextSecondary)
                    .padding(.top, 50)

                NavigationLink("지난 순간 모두 보기") {
                    CollectionView(recordStore: recordStore)
                }
                .font(.whisperControl)
                .foregroundStyle(Color.whisperTextSecondary)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(Color.whisperBackground.ignoresSafeArea())
        .navigationTitle("보관함")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("이전 달")

            Spacer()
            VStack(spacing: 2) {
                Text(displayedMonth.formatted(Date.FormatStyle().locale(Locale(identifier: "ko_KR")).year()))
                    .font(.whisperHandwriting(18))
                    .foregroundStyle(Color.whisperTextSecondary)
                Text(displayedMonth.formatted(Date.FormatStyle().locale(Locale(identifier: "ko_KR")).month(.wide)))
                    .font(.whisperHandwriting(34, bold: true))
                    .foregroundStyle(Color.whisperTextPrimary)
                    .padding(.horizontal, 8)
                    .background(alignment: .bottom) {
                        Capsule().fill(Color.whisperSurfaceHighlight).frame(height: 8)
                    }
            }
            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("다음 달")
        }
        .foregroundStyle(Color.whisperTextSecondary)
        .padding(.horizontal, 18)
        .padding(.top, 20)
    }

    private var monthJournals: [DailyJournal] {
        recordStore.journals
            .filter { calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    private var rows: [[DailyJournal]] {
        stride(from: 0, to: monthJournals.count, by: 3).map { start in
            Array(monthJournals[start..<min(start + 3, monthJournals.count)])
        }
    }

    private func shelfRow(_ journals: [DailyJournal]) -> some View {
        ZStack(alignment: .bottom) {
            Image("ArchiveShelf")
                .resizable()
                .frame(height: 35)
                .padding(.horizontal, 19)
                .offset(y: -13)
                .accessibilityHidden(true)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    Group {
                        if index < journals.count {
                            let journal = journals[index]
                            NavigationLink {
                                JournalDetailView(journalID: journal.id, recordStore: recordStore)
                            } label: {
                                VStack(spacing: 0) {
                                    Image(bottleAsset(for: journal.emotion))
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 88, height: 130)
                                    Text(journal.date.formatted(.dateTime.month().day()))
                                        .font(.whisperHandwriting(16))
                                        .foregroundStyle(Color.whisperTextPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(journal.date.whisperFullDayDescription), \(journal.emotion ?? "감정 미선택") 일기 열기")
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 150)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 165)
    }

    private func bottleAsset(for emotion: String?) -> String {
        switch emotion {
        case WhisperEmotion.calm.rawValue: "BottleCalm"
        case WhisperEmotion.tired.rawValue: "BottleTired"
        case WhisperEmotion.excitement.rawValue: "BottleExcited"
        case WhisperEmotion.anxiety.rawValue, "속상": "BottleAnxious"
        default: "BottleJoy"
        }
    }

    private func changeMonth(by offset: Int) {
        guard let next = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = next
    }
}
