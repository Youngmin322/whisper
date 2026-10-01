//
//  RecordFlowViews.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

enum WhisperJarSize {
    case welcome, hero, small, shelf, recordDetail
    
    var dimensions: CGSize {
        switch self {
        case .welcome: CGSize(width: 93, height: 124)
        case .hero: CGSize(width: 56, height: 74)
        case .small: CGSize(width: 47, height: 62)
        case .shelf: CGSize(width: 55, height: 73)
        case .recordDetail: CGSize(width: 76, height: 101)
        }
    }
}

struct WhisperJar: View {
    let size: WhisperJarSize
    var emotion: String? = nil
    
    var body: some View {
        let width = min(size.dimensions.width, size.dimensions.height * 82 / 119)
        FlameBottle(emotion: emotion, width: width)
            .frame(width: size.dimensions.width, height: size.dimensions.height)
            .accessibilityLabel("불꽃이 담긴 유리병")
    }
}

private struct RecordMonthSection: Identifiable {
    let month: Date
    let records: [WhisperRecord]

    var id: Date { month }
}

struct CollectionView: View {
    let recordStore: RecordStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""
    @State private var selectedEmotion: String?
    @State private var selectedCommitmentStatus: CommitmentLifecycleStatus?
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: WhisperSpacing.medium) {
                collectionHeader
                filterBar

                if recordStore.records.isEmpty && recordStore.journals.isEmpty {
                    ContentUnavailableView(
                        "아직 담긴 마음이 없어요",
                        systemImage: "flame",
                        description: Text("오늘의 마음을 기록하면 이곳에 하나씩 쌓여요.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else if filteredRecords.isEmpty && filteredJournals.isEmpty {
                    ContentUnavailableView {
                        Label("조건에 맞는 기록이 없어요", systemImage: "magnifyingglass")
                    } description: {
                        Text("검색어나 필터를 바꿔 다시 찾아보세요.")
                    } actions: {
                        Button("검색 조건 초기화", action: resetFilters)
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    if !filteredJournals.isEmpty {
                        Text("완성 일기")
                            .font(.whisperSectionTitle)
                            .foregroundStyle(Color.whisperTextPrimary)
                        ForEach(filteredJournals) { journal in
                            NavigationLink {
                                JournalDetailView(journalID: journal.id, recordStore: recordStore)
                            } label: {
                                VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                                    Text("완성 일기 · \(journal.displayDate.whisperDateDescription)")
                                        .font(.whisperMetadata)
                                        .foregroundStyle(Color.whisperAccentText)
                                    Text(journal.title.isEmpty ? journal.displayDate.whisperDateDescription : journal.title)
                                        .font(.whisperSectionTitle)
                                        .foregroundStyle(Color.whisperTextPrimary)
                                    Text(journal.body)
                                        .font(.whisperBody)
                                        .foregroundStyle(Color.whisperTextSecondary)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(WhisperSpacing.large)
                                .whisperCardStyle(fill: .whisperSurfaceDefault, border: .whisperBorderSubtle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("완성 일기, \(journal.displayDate.whisperFullDayDescription), \(journal.title)")
                        }
                    }
                    if !filteredRecords.isEmpty {
                        Text("모든 순간")
                            .font(.whisperSectionTitle)
                            .foregroundStyle(Color.whisperTextPrimary)
                    }
                    ForEach(monthSections) { section in
                        Text(monthTitle(section.month))
                            .font(.whisperSectionTitle)
                            .foregroundStyle(Color.whisperTextPrimary)
                            .padding(.top, WhisperSpacing.xSmall)

                        ForEach(section.records) { record in
                            NavigationLink {
                                RecordDetailView(
                                    record: record,
                                    recordStore: recordStore
                                )
                            } label: {
                                journalRecordCard(for: record)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(recordAccessibilityLabel(record))
                        }
                    }
                }
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 30)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Color.whisperBackground)
        .navigationTitle("보관함")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "일기와 순간 검색")
    }

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                        collectionIntroduction
                        CollectionFlameJar(storedFlameCount: storedFlameCount, width: 82, emotions: storedFlameEmotions)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    HStack(spacing: WhisperSpacing.small) {
                        collectionIntroduction
                        CollectionFlameJar(storedFlameCount: storedFlameCount, width: 82, emotions: storedFlameEmotions)
                    }
                }
            }
            .padding(.horizontal, WhisperSpacing.medium)
            .padding(.vertical, 14)
            .frame(minHeight: 142)
            .whisperCardStyle(
                fill: .whisperSurfaceHighlight,
                border: .whisperBorderSubtle,
                hasShadow: true
            )
        }
    }

    private var collectionIntroduction: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
            Text("마음이 머무는 곳")
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperAccentText)

            Text(summaryTitle)
                .font(.whisperNavigationTitle)
                .foregroundStyle(Color.whisperTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(monthlySummary)
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var storedFlameCount: Int {
        recordStore.records.count
    }

    private var storedFlameEmotions: [String?] {
        recordStore.records
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map(\.emotion)
    }

    private var filteredJournals: [DailyJournal] {
        guard selectedCommitmentStatus == nil else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return recordStore.journals.filter { journal in
            (query.isEmpty
                || journal.title.localizedCaseInsensitiveContains(query)
                || journal.body.localizedCaseInsensitiveContains(query)
                || journal.reflection.localizedCaseInsensitiveContains(query)
                || (journal.emotion?.localizedCaseInsensitiveContains(query) ?? false))
                && (selectedEmotion == nil || journal.emotion == selectedEmotion)
        }
    }

    private var summaryTitle: String {
        if storedFlameCount == 0 && recordStore.journals.isEmpty {
            return "첫 기록을 기다리고 있어요"
        }
        return "일기 \(recordStore.journals.count)개 · 순간 \(storedFlameCount)개를\n간직하고 있어요"
    }

    private var monthlySummary: String {
        let count = recordStore.records.filter {
            Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month)
        }.count
        return count == 0
            ? "이번 달 새로 담은 마음이 없어요"
            : "이번 달 새로 담은 마음 \(count)개"
    }

    private func storedCommitment(for record: WhisperRecord) -> WhisperCommitment? {
        guard CommitmentReminderFeature.isEnabled else { return nil }
        return recordStore.commitments.first { $0.sourceRecordID == record.id }
    }

    private func recordAccessibilityLabel(_ record: WhisperRecord) -> String {
        let base = "순간 기록, \(record.title), \(record.createdAt.whisperFullDayDescription)"
        guard let status = storedCommitment(for: record)?.lifecycleStatus() else {
            return base
        }
        let statusDescription = switch status {
        case .active: "다시 만나기를 기다리는 결심"
        case .paused: "다시 만나기를 잠시 멈춘 결심"
        case .released: "놓아준 마음"
        }
        return "\(base), \(statusDescription)"
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button {
                    selectedEmotion = nil
                    selectedCommitmentStatus = nil
                } label: {
                    filterChip(
                        title: "전체",
                        isActive: !hasSelectedFilterChips,
                        showsMenuIndicator: false
                    )
                }
                .buttonStyle(.plain)

                Menu {
                    Button("전체 감정") { selectedEmotion = nil }
                    ForEach(WhisperEmotion.allCases) { emotion in
                        Button(emotion.rawValue) {
                            selectedEmotion = emotion.rawValue
                        }
                    }
                } label: {
                    filterChip(
                        title: selectedEmotion ?? "감정",
                        isActive: selectedEmotion != nil,
                        showsMenuIndicator: true
                    )
                }

                if CommitmentReminderFeature.isEnabled {
                    Menu {
                        Button("모든 상태") { selectedCommitmentStatus = nil }
                        Button("기억 중") { selectedCommitmentStatus = .active }
                        Button("잠시 쉬는 중") { selectedCommitmentStatus = .paused }
                        Button("놓아준 마음") { selectedCommitmentStatus = .released }
                    } label: {
                        filterChip(
                            title: selectedCommitmentStatus.map(commitmentStatusTitle) ?? "다시 만나기",
                            isActive: selectedCommitmentStatus != nil,
                            showsMenuIndicator: true
                        )
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func filterChip(
        title: String,
        isActive: Bool,
        showsMenuIndicator: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if showsMenuIndicator {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .font(.whisperControl)
        .foregroundStyle(isActive ? Color.whisperTextOnAccent : Color.whisperTextPrimary)
        .padding(.horizontal, WhisperSpacing.medium)
        .frame(minHeight: WhisperSize.controlCompact)
        .background(
            Capsule()
                .fill(isActive ? Color.whisperAccent : Color.whisperSurfaceDefault)
                .overlay {
                    Capsule()
                        .stroke(
                            isActive ? Color.whisperAccent : Color.whisperBorderSubtle,
                            lineWidth: 1
                        )
                }
        )
    }

    private var hasSelectedFilterChips: Bool {
        selectedEmotion != nil || selectedCommitmentStatus != nil
    }

    private var filteredRecords: [WhisperRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return recordStore.records.filter { record in
            let matchesSearch = query.isEmpty ||
                record.title.localizedCaseInsensitiveContains(query) ||
                record.content.localizedCaseInsensitiveContains(query)
            let matchesEmotion = selectedEmotion == nil || record.emotion == selectedEmotion
            let matchesCommitmentStatus = selectedCommitmentStatus == nil ||
                storedCommitment(for: record)?.lifecycleStatus() == selectedCommitmentStatus
            return matchesSearch && matchesEmotion && matchesCommitmentStatus
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private var monthSections: [RecordMonthSection] {
        let grouped = Dictionary(grouping: filteredRecords) { record in
            Calendar.current.dateInterval(of: .month, for: record.createdAt)?.start
                ?? Calendar.current.startOfDay(for: record.createdAt)
        }

        return grouped.keys.sorted(by: >).map { month in
            RecordMonthSection(
                month: month,
                records: (grouped[month] ?? []).sorted { $0.createdAt > $1.createdAt }
            )
        }
    }

    private func monthTitle(_ month: Date) -> String {
        month.formatted(
            .dateTime.year().month(.wide).locale(Locale(identifier: "ko_KR"))
        )
    }

    private func commitmentStatusTitle(_ status: CommitmentLifecycleStatus) -> String {
        switch status {
        case .active: "기억 중"
        case .paused: "잠시 쉬는 중"
        case .released: "놓아준 마음"
        }
    }

    private func resetFilters() {
        searchText = ""
        selectedEmotion = nil
        selectedCommitmentStatus = nil
    }
    
    private func journalRecordCard(for record: WhisperRecord) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            HStack(spacing: WhisperSpacing.small) {
                VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                    Text("순간 기록")
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperAccentText)
                    Text(record.title)
                        .font(.whisperSectionTitle)
                        .foregroundStyle(Color.whisperTextPrimary)
                        .lineLimit(2)

                    Text(recordDateLabel(record.createdAt))
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextSecondary)
                }
                Spacer(minLength: 0)
                FlameCharacter(emotion: record.emotion, size: 42)
            }

            Text(record.content)
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextPrimary)
                .lineSpacing(3)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.whisperDivider)
                .frame(height: 1)

            HStack(spacing: WhisperSpacing.xSmall) {
                Text(recordTimestampLabel(record.createdAt))
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .lineLimit(1)

                Spacer(minLength: WhisperSpacing.xSmall)

                if record.photoData != nil {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.whisperTextSecondary)
                        .accessibilityLabel("사진 있음")
                }

                Label {
                    Text(recordStatus(for: record).title)
                        .font(.whisperLabel)
                } icon: {
                    Image(systemName: recordStatus(for: record).icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.whisperAccent)
                }
                .foregroundStyle(Color.whisperTextSecondary)
                .lineLimit(1)
            }
        }
        .padding(WhisperSpacing.large)
        .whisperCardStyle(
            fill: .whisperSurfaceDefault,
            border: .whisperBorderSubtle
        )
        .contentShape(Rectangle())
    }

    private func recordStatus(for record: WhisperRecord) -> (title: String, icon: String) {
        guard let status = storedCommitment(for: record)?.lifecycleStatus() else {
            return ("간직함", "flame.fill")
        }

        return switch status {
        case .active: ("기억 중", "flame.fill")
        case .paused: ("쉬는 중", "moon.zzz.fill")
        case .released: ("놓아줌", "checkmark")
        }
    }

    private func recordDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func recordTimestampLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E) a h:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    CollectionView(recordStore: RecordStore(isStoredInMemoryOnly: true))
}
