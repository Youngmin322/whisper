//
//  RecordFlowViews.swift
//  Whisper
//

import SwiftUI

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
        let width = min(size.dimensions.width, size.dimensions.height / WhisperJarDesign.heightToWidth)
        FlameBottle(emotion: emotion, width: width)
            .frame(width: size.dimensions.width, height: size.dimensions.height)
            .accessibilityLabel(String(localized: "불꽃이 담긴 유리병", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
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
                        String(localized: "아직 담긴 마음이 없어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale),
                        systemImage: "flame",
                        description: Text(String(localized: "오늘의 마음을 기록하면 이곳에 하나씩 쌓여요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else if filteredRecords.isEmpty && filteredJournals.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "조건에 맞는 기록이 없어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), systemImage: "magnifyingglass")
                    } description: {
                        Text(String(localized: "검색어나 필터를 바꿔 다시 찾아보세요.", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                    } actions: {
                        Button(String(localized: "검색 조건 초기화", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), action: resetFilters)
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    if !filteredJournals.isEmpty {
                        Text(String(localized: "완성 일기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                            .font(.whisperSectionTitle)
                            .foregroundStyle(Color.whisperTextPrimary)
                        ForEach(filteredJournals) { journal in
                            NavigationLink {
                                JournalDetailView(journalID: journal.id, recordStore: recordStore)
                            } label: {
                                VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                                    Text(String(localized: "완성 일기 · \(journal.displayDate.whisperDateDescription)", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
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
                            .accessibilityLabel(String(localized: "완성 일기, \(journal.displayDate.whisperFullDayDescription), \(journal.title)", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                        }
                    }
                    if !filteredRecords.isEmpty {
                        Text(String(localized: "모든 순간", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
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
        .navigationTitle(String(localized: "보관함", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: String(localized: "일기와 순간 검색", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
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
            Text(String(localized: "마음이 머무는 곳", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
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
                || WhisperEmotion.searchText(for: journal.emotion).localizedCaseInsensitiveContains(query))
                && (selectedEmotion == nil || journal.emotion == selectedEmotion)
        }
    }

    private var summaryTitle: String {
        if storedFlameCount == 0 && recordStore.journals.isEmpty {
            return String(localized: "첫 기록을 기다리고 있어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        }
        return String(localized: "일기 \(recordStore.journals.count)개 · 순간 \(storedFlameCount)개를\n간직하고 있어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
    }

    private var monthlySummary: String {
        let count = recordStore.records.filter {
            Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month)
        }.count
        return count == 0
            ? String(localized: "이번 달 새로 담은 마음이 없어요", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
            : String(localized: "이번 달 새로 담은 마음 \(count)개", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
    }

    private func storedCommitment(for record: WhisperRecord) -> WhisperCommitment? {
        guard CommitmentReminderFeature.isEnabled else { return nil }
        return recordStore.commitments.first { $0.sourceRecordID == record.id }
    }

    private func recordAccessibilityLabel(_ record: WhisperRecord) -> String {
        let base = String(localized: "순간 기록, \(record.title), \(record.createdAt.whisperFullDayDescription)", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        guard let status = storedCommitment(for: record)?.lifecycleStatus() else {
            return base
        }
        let statusDescription = switch status {
        case .active: String(localized: "다시 만나기를 기다리는 결심", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case .paused: String(localized: "다시 만나기를 잠시 멈춘 결심", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case .released: String(localized: "놓아준 마음", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
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
                        title: String(localized: "전체", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale),
                        isActive: !hasSelectedFilterChips,
                        showsMenuIndicator: false
                    )
                }
                .buttonStyle(.plain)

                Menu {
                    Button(String(localized: "전체 감정", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) { selectedEmotion = nil }
                    ForEach(WhisperEmotion.allCases) { emotion in
                        Button(emotion.displayName) {
                            selectedEmotion = emotion.rawValue
                        }
                    }
                } label: {
                    filterChip(
                        title: WhisperEmotion.displayName(for: selectedEmotion) ?? String(localized: "감정", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale),
                        isActive: selectedEmotion != nil,
                        showsMenuIndicator: true
                    )
                }

                if CommitmentReminderFeature.isEnabled {
                    Menu {
                        Button(String(localized: "모든 상태", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) { selectedCommitmentStatus = nil }
                        Button(String(localized: "기억 중", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) { selectedCommitmentStatus = .active }
                        Button(String(localized: "잠시 쉬는 중", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) { selectedCommitmentStatus = .paused }
                        Button(String(localized: "놓아준 마음", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) { selectedCommitmentStatus = .released }
                    } label: {
                        filterChip(
                            title: selectedCommitmentStatus.map(commitmentStatusTitle) ?? String(localized: "다시 만나기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale),
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
                .fill(isActive ? Color.whisperButtonBackground : Color.whisperSurfaceDefault)
                .overlay {
                    Capsule()
                        .stroke(
                            isActive ? Color.whisperButtonBackground : Color.whisperBorderSubtle,
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
            .dateTime.year().month(.wide).locale(WhisperLocalization.locale)
        )
    }

    private func commitmentStatusTitle(_ status: CommitmentLifecycleStatus) -> String {
        switch status {
        case .active: String(localized: "기억 중", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case .paused: String(localized: "잠시 쉬는 중", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
        case .released: String(localized: "놓아준 마음", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)
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
                    Text(String(localized: "순간 기록", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
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
                        .accessibilityLabel(String(localized: "사진 있음", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
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
            return (String(localized: "간직함", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), "flame.fill")
        }

        return switch status {
        case .active: (String(localized: "기억 중", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), "flame.fill")
        case .paused: (String(localized: "쉬는 중", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), "moon.zzz.fill")
        case .released: (String(localized: "놓아줌", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale), "checkmark")
        }
    }

    private func recordDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WhisperLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return formatter.string(from: date)
    }

    private func recordTimestampLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WhisperLocalization.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMEdjm")
        return formatter.string(from: date)
    }
}

#Preview {
    CollectionView(recordStore: RecordStore(isStoredInMemoryOnly: true))
}
