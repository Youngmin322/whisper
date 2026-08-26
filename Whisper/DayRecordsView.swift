//
//  DayRecordsView.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

struct DayRecordsView: View {
    let date: Date
    let recordStore: RecordStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(date.emberFullDayDescription)
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
                    .padding(.top, 12)

                if records.isEmpty {
                    ContentUnavailableView(
                        "이날의 기록이 없어요",
                        systemImage: "flame",
                        description: Text("기록이 생기면 이곳에서 다시 볼 수 있어요.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 320)
                } else {
                    ForEach(records) { record in
                        NavigationLink {
                            RecordDetailView(record: record, recordStore: recordStore)
                        } label: {
                            recordCard(for: record)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(record.createdAt.emberTimeDescription), \(record.title)"
                        )
                    }
                }
            }
            .padding(.horizontal, EmberLayout.screenHorizontalPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color.emberBackground)
        .navigationTitle("이날의 기록")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var records: [EmberRecord] {
        recordStore.records(on: date, calendar: calendar)
    }

    private func recordCard(for record: EmberRecord) -> some View {
        HStack(alignment: .top, spacing: 14) {
            EmberJar(size: .small)

            VStack(alignment: .leading, spacing: 6) {
                Text(record.createdAt.emberTimeDescription)
                    .font(.emberCaption)
                    .foregroundStyle(Color.emberTextSecondary)

                Text(record.title)
                    .font(.emberBodyEmphasis)
                    .foregroundStyle(Color.emberTextPrimary)
                    .lineLimit(1)

                Text(record.content)
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.emberTextSecondary)
                .padding(.top, 4)
        }
        .padding(16)
        .emberCardStyle(
            fill: .emberSurfaceDefault,
            border: .emberBorderSubtle,
            cornerRadius: EmberRadius.large
        )
        .contentShape(Rectangle())
    }

    private var calendar: Calendar {
        Calendar(identifier: .iso8601)
    }
}

private struct DayRecordsPreview: View {
    private let recordStore: RecordStore

    init() {
        let store = RecordStore(isStoredInMemoryOnly: true)
        store.add(title: "아침의 마음", content: "조금 천천히 하루를 시작해 보기로 했다.")
        store.add(title: "오늘의 결심", content: "작은 일 하나를 끝까지 마무리했다.")
        recordStore = store
    }

    var body: some View {
        NavigationStack {
            DayRecordsView(date: .now, recordStore: recordStore)
        }
    }
}

#Preview { DayRecordsPreview() }
