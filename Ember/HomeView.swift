//
//  HomeView.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

struct HomeView: View {
    let recordStore: RecordStore
    @State private var isQuickRecordPresented = false
    @State private var isDetailRecordPresented = false
    @State private var shouldOpenDetailAfterSheetDismisses = false
    @State private var recordDraft = RecordDraft()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
                .padding(.horizontal, EmberLayout.screenHorizontalPadding)
                .padding(.top, 10)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    todayCard
                    rhythmCard
                    memoryCard
                }
                .padding(.horizontal, EmberLayout.screenHorizontalPadding)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.emberBackground)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(
            isPresented: $isQuickRecordPresented,
            onDismiss: openDetailAfterSheetDismissesIfNeeded
        ) {
            QuickRecordView(
                draft: $recordDraft,
                onSave: { saveDraft() },
                onOpenDetail: {
                    shouldOpenDetailAfterSheetDismisses = true
                }
            )
            .presentationDetents([.height(444)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .navigationDestination(isPresented: $isDetailRecordPresented) {
            DetailedRecordView(draft: $recordDraft) { emotion, photoData in
                saveDraft(
                    emotion: emotion,
                    photoData: photoData
                )
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now.emberDayDescription)
                .font(.emberMetadata)
                .foregroundStyle(Color.emberTextSecondary)
            Text("오늘의 기록")
                .font(.emberScreenTitle)
                .foregroundStyle(Color.emberTextPrimary)
        }
    }
    
    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘 떠오른 마음")
                        .font(.emberControl)
                        .foregroundStyle(Color.emberAccentText)
                    
                    Text("지금 가장 마음에 남는 것은 무엇인가요?")
                        .font(.emberBodyEmphasis)
                        .foregroundStyle(Color.emberTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                EmberJarAnimation(size: .home)
            }
            
            Button {
                isQuickRecordPresented = true
            } label: {
                Text("기록하기")
            }
            .buttonStyle(.emberPrimary(size: .compact))
            .padding(.top, hasTodayRecord ? 14 : 24)
        }
        .padding(20)
        .emberCardStyle(
            fill: .emberSurfaceHighlight,
            border: .emberBorderSubtle,
            cornerRadius: EmberRadius.card,
            hasShadow: true
        )
    }
    
    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("이번 주 기록 리듬").font(.emberSectionTitle)
                Spacer()
                Text("\(recordStore.recordCount(inWeekOf: .now, calendar: calendar)) / 7")
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
            }
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                    rhythmDay(date: date, title: weekdayTitles[index])
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .emberCardStyle(fill: .emberSurfaceDefault, border: .emberBorderSubtle, cornerRadius: EmberRadius.large)
    }

    @ViewBuilder
    private func rhythmDay(date: Date, title: String) -> some View {
        if recordStore.hasRecord(on: date, calendar: calendar) {
            NavigationLink {
                DayRecordsView(date: date, recordStore: recordStore)
            } label: {
                rhythmDayLabel(date: date, title: title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(date.emberFullDayDescription) 기록 보기")
        } else if calendar.isDateInToday(date) {
            Button {
                isQuickRecordPresented = true
            } label: {
                rhythmDayLabel(date: date, title: title)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("오늘 기록하기")
        } else {
            rhythmDayLabel(date: date, title: title)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(date.emberFullDayDescription), 기록 없음")
        }
    }

    private func rhythmDayLabel(date: Date, title: String) -> some View {
        let isToday = calendar.isDateInToday(date)
        let hasRecord = recordStore.hasRecord(on: date, calendar: calendar)

        return VStack(spacing: 7) {
            Text(title)
                .font(.emberCaption)
                .foregroundStyle(Color.emberTextSecondary)

            ZStack {
                Circle()
                    .fill(isToday ? Color.emberAccent : Color.emberSurfaceSubtle)
                    .frame(width: 28, height: 28)

                if hasRecord {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isToday ? Color.white : Color.emberAccent)
                } else if isToday {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var memoryCard: some View {
        if let record = recordStore.resurfacingRecord() {
            NavigationLink {
                RecordDetailView(record: record, recordStore: recordStore)
            } label: {
                resurfacingCard(for: record)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("다시 만난 불꽃, \(record.title)")
        } else {
            waitingMemoryCard
        }
    }

    private func resurfacingCard(for record: EmberRecord) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("다시 만난 불꽃")
                    .font(.emberControl)
                    .foregroundStyle(Color.emberAccentText)
                
                Text(record.title)
                    .font(.emberBodyEmphasis)
                    .foregroundStyle(Color.emberTextPrimary)

                Text(record.content)
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
                    .lineLimit(2)

                Text("\(recordStore.daysSince(record))일 전의 기록 보기")
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
                    .padding(.top, 4)
            }
            
            Spacer(minLength: 4)
            
            EmberJar(size: .small)
        }
        .padding(18)
        .emberCardStyle(fill: .emberSurfaceSubtle, border: .emberBorderSubtle, cornerRadius: EmberRadius.large)
        .contentShape(Rectangle())
    }

    private var waitingMemoryCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("다시 만난 불꽃")
                    .font(.emberControl)
                    .foregroundStyle(Color.emberAccentText)

                Text("아직 잠든 불꽃이 없어요")
                    .font(.emberBodyEmphasis)
                    .foregroundStyle(Color.emberTextPrimary)

                Text("30일이 지난 기록을 이곳에서 다시 만나요.")
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
            }

            Spacer(minLength: 4)

            EmberJar(size: .small)
        }
        .padding(18)
        .emberCardStyle(
            fill: .emberSurfaceSubtle,
            border: .emberBorderSubtle,
            cornerRadius: EmberRadius.large
        )
    }
    
    private var hasTodayRecord: Bool {
        recordStore.hasRecord(on: .now, calendar: calendar)
    }

    private func saveDraft(
        emotion: String? = nil,
        photoData: Data? = nil
    ) {
        recordStore.add(
            title: recordDraft.titleForSaving,
            content: recordDraft.contentForSaving,
            emotion: emotion,
            photoData: photoData
        )
        recordDraft = RecordDraft()
    }

    private func openDetailAfterSheetDismissesIfNeeded() {
        guard shouldOpenDetailAfterSheetDismisses else { return }
        shouldOpenDetailAfterSheetDismisses = false
        isDetailRecordPresented = true
    }
    
    private var calendar: Calendar {
        Calendar(identifier: .iso8601)
    }

    private var weekdayTitles: [String] {
        ["월", "화", "수", "목", "금", "토", "일"]
    }

    private var weekDates: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else {
            return []
        }

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: week.start)
        }
    }
}

private struct HomePreview: View {
    private let recordStore: RecordStore

    init() {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let oldDate = Calendar.current.date(byAdding: .day, value: -84, to: .now) ?? .now
        store.add(
            title: "그때의 작은 결심",
            content: "조급해하지 말고 오늘 할 수 있는 한 가지에 집중하자.",
            createdAt: oldDate
        )
        recordStore = store
    }

    var body: some View {
        NavigationStack {
            HomeView(recordStore: recordStore)
        }
    }
}

#Preview { HomePreview() }
