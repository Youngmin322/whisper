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
    
    var body: some View {
        Image.whisper
            .resizable()
            .scaledToFit()
            .frame(width: size.dimensions.width, height: size.dimensions.height)
            .accessibilityLabel("불꽃이 담긴 유리병")
    }
}

struct DetailedRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: RecordDraft
    @State private var selectedEmotion: String?
    @State private var photoData: Data?
    @State private var isSaved = false
    @State private var isSaveErrorPresented = false
    @State private var isEmotionPickerPresented = false
    let onSave: (String?, Data?) -> Bool
    private let contentLimit = 1_000
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Date.now.whisperFullDayDescription)
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .padding(.top, 12)
                fieldLabel(RecordWritingCopy.titleLabel)
                TextField(RecordWritingCopy.titleExample, text: $draft.title)
                    .font(.whisperBodyLarge)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
                    .accessibilityIdentifier("record.titleField")

                Text(RecordWritingCopy.titleHelp)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
                
                fieldLabel(RecordWritingCopy.contentLabel)
                ZStack(alignment: .bottomTrailing) {
                    TextField(RecordWritingCopy.contentExample, text: $draft.content, axis: .vertical)
                        .font(.whisperBodyLarge)
                        .lineSpacing(5)
                        .lineLimit(6 ... 8)
                        .padding(18)
                        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
                        .onChange(of: draft.content) { _, newValue in
                            guard newValue.count > contentLimit else { return }
                            draft.content = String(newValue.prefix(contentLimit))
                        }
                        .accessibilityIdentifier("record.contentField")
                    Text("\(draft.content.count) / \(contentLimit.formatted())")
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .padding(16)
                }
                .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
                
                fieldLabel("기록에 더하기")
                HStack(spacing: 10) {
                    recordChip(
                        icon: "face.smiling",
                        title: selectedEmotion ?? "감정"
                    ) {
                        isEmotionPickerPresented = true
                    }
                }

                PhotoAttachmentEditor(photoData: $photoData)
                
                Label("결심이 담겨 있다면 저장한 뒤 Whisper가 기억할지 물어봐요.", systemImage: "bell")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.bottom, 90)
        }
        .scrollIndicators(.hidden)
        .background(Color.whisperBackground)
        .safeAreaInset(edge: .bottom) {
            Button("기록 저장") {
                if onSave(selectedEmotion, photoData) {
                    isSaved = true
                } else {
                    isSaveErrorPresented = true
                }
            }
            .buttonStyle(.whisperPrimary)
            .disabled(!draft.canSave)
            .accessibilityIdentifier("record.saveButton")
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("상세 기록")
        .navigationBarTitleDisplayMode(.inline)
        .alert("기록을 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("다시 시도") {
                if onSave(selectedEmotion, photoData) {
                    isSaved = true
                }
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("작성한 내용은 그대로 두었어요. 잠시 후 다시 시도해 주세요.")
        }
        .sheet(
            isPresented: $isSaved,
            onDismiss: { dismiss() }
        ) {
            SavedRecordSheet {
                isSaved = false
            }
            .presentationDetents([.height(312), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isEmotionPickerPresented) {
            EmotionPickerView(selectedEmotion: $selectedEmotion)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.clear)
        }
    }
    
    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.whisperFieldLabel).foregroundStyle(Color.whisperTextPrimary)
    }
    
    private func recordChip(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.whisperControl)
                .foregroundStyle(Color.whisperTextPrimary)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.whisperSurfaceSubtle, in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SavedRecordSheet: View {
    let onHome: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("오늘의 불꽃을 담았어요")
                    .font(.whisperNavigationTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
                Text("기록은 보관함에서 언제든 다시 꺼내보고\n결심이 보이면 Whisper가 기억할지 물어볼게요.")
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                WhisperJar(size: .hero).padding(.vertical, 4)
                Button("홈으로 돌아가기", action: onHome)
                    .buttonStyle(.whisperPrimary(size: .compact))
                    .padding(.top, 2)
            }
            .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("record.savedSheet")
    }
}

struct CollectionView: View {
    let recordStore: RecordStore
    @State private var searchText = ""
    @State private var selectedEmotion: String?
    @State private var selectedCommitmentStatus: CommitmentLifecycleStatus?
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: WhisperSpacing.medium) {
                collectionHeader
                searchField
                filterBar

                if recordStore.records.isEmpty {
                    ContentUnavailableView(
                        "아직 담긴 불꽃이 없어요",
                        systemImage: "flame",
                        description: Text("오늘의 마음을 기록하면 이곳에 하나씩 쌓여요.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else if filteredRecords.isEmpty {
                    ContentUnavailableView {
                        Label("조건에 맞는 불꽃이 없어요", systemImage: "magnifyingglass")
                    } description: {
                        Text("검색어나 필터를 바꿔 다시 찾아보세요.")
                    } actions: {
                        Button("검색 조건 초기화", action: resetFilters)
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    ForEach(filteredRecords) { record in
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
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(Color.whisperBackground)
        .navigationBarHidden(true)
    }

    private var collectionHeader: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text("불꽃 보관함")
                .font(.whisperScreenTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            HStack(spacing: WhisperSpacing.small) {
                VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                    Text("Whisper가 간직한 마음")
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

                CollectionFlameJar(
                    storedFlameCount: storedFlameCount,
                    width: 72
                )
            }
            .padding(.horizontal, WhisperSpacing.medium)
            .padding(.vertical, 14)
            .frame(minHeight: 132)
            .whisperCardStyle(
                fill: .whisperSurfaceHighlight,
                border: .whisperBorderSubtle,
                hasShadow: true
            )
        }
    }

    private var storedFlameCount: Int {
        recordStore.records.count
    }

    private var summaryTitle: String {
        storedFlameCount == 0
            ? "아직 간직한 불꽃이 없어요"
            : "\(storedFlameCount)개의 불꽃을\n간직하고 있어요"
    }

    private var monthlySummary: String {
        let count = recordStore.records.filter {
            Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month)
        }.count
        return count == 0
            ? "이번 달 새로 담은 불꽃이 없어요"
            : "이번 달 새로 담은 불꽃 \(count)개"
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.whisperTextSecondary)

            TextField("제목이나 내용 검색", text: $searchText)
                .font(.whisperBody)
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.whisperTextSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            Color.whisperSurfaceSubtle,
            in: RoundedRectangle(
                cornerRadius: WhisperRadius.medium,
                style: .continuous
            )
        )
    }

    private func storedCommitment(for record: WhisperRecord) -> WhisperCommitment? {
        recordStore.commitments.first { $0.sourceRecordID == record.id }
    }

    private func recordAccessibilityLabel(_ record: WhisperRecord) -> String {
        let base = "\(record.title), \(record.createdAt.whisperFullDayDescription)"
        guard let status = storedCommitment(for: record)?.lifecycleStatus() else {
            return base
        }
        let statusDescription = switch status {
        case .active: "기억 중인 불꽃"
        case .paused: "잠시 쉬는 불꽃"
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

                Menu {
                    Button("모든 불꽃") { selectedCommitmentStatus = nil }
                    Button("기억 중") { selectedCommitmentStatus = .active }
                    Button("잠시 쉬는 중") { selectedCommitmentStatus = .paused }
                    Button("놓아준 마음") { selectedCommitmentStatus = .released }
                } label: {
                    filterChip(
                        title: selectedCommitmentStatus.map(commitmentStatusTitle) ?? "불꽃 상태",
                        isActive: selectedCommitmentStatus != nil,
                        showsMenuIndicator: true
                    )
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
        WhisperFilterChip(
            title: title,
            isSelected: isActive,
            showsMenuIndicator: showsMenuIndicator
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
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text(record.title)
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .lineLimit(2)

                Text(recordDateLabel(record.createdAt))
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
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

private struct DetailedRecordPreview: View {
    @State private var draft = RecordDraft()

    var body: some View {
        NavigationStack {
            DetailedRecordView(
                draft: $draft,
                onSave: { _, _ in true }
            )
        }
    }
}

#Preview { DetailedRecordPreview() }

#Preview {
    CollectionView(recordStore: RecordStore(isStoredInMemoryOnly: true))
}
