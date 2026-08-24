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
                onSave: saveDraft,
                onOpenDetail: {
                    shouldOpenDetailAfterSheetDismisses = true
                }
            )
            .presentationDetents([.height(444)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .navigationDestination(isPresented: $isDetailRecordPresented) {
            DetailedRecordView(draft: $recordDraft) {
                saveDraft()
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
                ForEach(Array(["월", "화", "수", "목", "금", "토", "일"].enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 7) {
                        Text(day).font(.emberCaption).foregroundStyle(Color.emberTextSecondary)
                        ZStack {
                            Circle().fill(isToday(index) ? Color.emberAccent : Color.emberSurfaceSubtle).frame(width: 28, height: 28)
                            if hasRecord(onWeekdayIndex: index) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isToday(index) ? Color.white : Color.emberAccent)
                            } else if isToday(index) {
                                Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .emberCardStyle(fill: .emberSurfaceDefault, border: .emberBorderSubtle, cornerRadius: EmberRadius.large)
    }
    
    private var memoryCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("다시 만난 불꽃")
                    .font(.emberControl)
                    .foregroundStyle(Color.emberAccentText)
                
                Text("그때의 결심을 오늘 다시 꺼내볼까요?")
                    .font(.emberBodyEmphasis)
                    .foregroundStyle(Color.emberTextPrimary)
                
                Text("84일 전의 기록 보기")
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
                    .padding(.top, 8)
            }
            
            Spacer(minLength: 4)
            
            EmberJar(size: .small)
        }
        .padding(18)
        .emberCardStyle(fill: .emberSurfaceSubtle, border: .emberBorderSubtle, cornerRadius: EmberRadius.large)
    }
    
    private var hasTodayRecord: Bool {
        recordStore.hasRecord(on: .now, calendar: calendar)
    }

    private func saveDraft() {
        recordStore.add(
            title: recordDraft.titleForSaving,
            content: recordDraft.contentForSaving
        )
        recordDraft = RecordDraft()
    }

    private func openDetailAfterSheetDismissesIfNeeded() {
        guard shouldOpenDetailAfterSheetDismisses else { return }
        shouldOpenDetailAfterSheetDismisses = false
        isDetailRecordPresented = true
    }
    
    private func isToday(_ weekdayIndex: Int) -> Bool {
        weekdayIndex == mondayBasedWeekdayIndex(for: .now)
    }
    
    private func hasRecord(onWeekdayIndex weekdayIndex: Int) -> Bool {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now),
              let date = calendar.date(byAdding: .day, value: weekdayIndex, to: week.start)
        else {
            return false
        }
        return recordStore.hasRecord(on: date, calendar: calendar)
    }
    
    private var calendar: Calendar {
        Calendar(identifier: .iso8601)
    }
    
    private func mondayBasedWeekdayIndex(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 6 : weekday - 2
    }
}

#Preview {
    NavigationStack {
        HomeView(recordStore: RecordStore(isStoredInMemoryOnly: true))
    }
}
