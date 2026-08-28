//
//  RecordFlowViews.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

enum WhisperJarSize {
    case welcome, hero, small, shelf
    
    var dimensions: CGSize {
        switch self {
        case .welcome: CGSize(width: 93, height: 124)
        case .hero: CGSize(width: 56, height: 74)
        case .small: CGSize(width: 47, height: 62)
        case .shelf: CGSize(width: 55, height: 73)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("불꽃 보관함")
                .font(.whisperScreenTitle)
                .padding(.top, 18)

            searchField
            filterBar

            ScrollView {
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
                }

                ForEach(monthlyShelves, id: \.title) { shelf in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(shelf.title).font(.whisperSectionTitle)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                            alignment: .leading,
                            spacing: 14
                        ) {
                            ForEach(shelf.records) { record in
                                NavigationLink {
                                    RecordDetailView(
                                        record: record,
                                        recordStore: recordStore
                                    )
                                } label: {
                                    ZStack(alignment: .bottomTrailing) {
                                        WhisperJar(size: .shelf)

                                        if record.photoData != nil {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Color.white)
                                                .frame(width: 20, height: 20)
                                                .background(Color.whisperAccent, in: Circle())
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .overlay(alignment: .topLeading) {
                                        if let commitment = storedCommitment(for: record) {
                                            commitmentStatusBadge(commitment.lifecycleStatus())
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    recordAccessibilityLabel(record)
                                )
                            }
                        }
                        Rectangle().fill(Color.whisperDivider).frame(height: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .scrollIndicators(.hidden)
        .background(Color.whisperBackground)
        .navigationBarHidden(true)
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

    private func commitmentStatusBadge(
        _ status: CommitmentLifecycleStatus
    ) -> some View {
        let icon = switch status {
        case .active: "sparkles"
        case .paused: "moon.zzz.fill"
        case .released: "checkmark"
        }

        return Image(systemName: icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: 22, height: 22)
            .background(Color.whisperAccent, in: Circle())
            .accessibilityHidden(true)
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
                        systemImage: "face.smiling",
                        isActive: selectedEmotion != nil
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
                        systemImage: "sparkles",
                        isActive: selectedCommitmentStatus != nil
                    )
                }

                if hasActiveFilters {
                    Button("초기화", action: resetFilters)
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperAccentText)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func filterChip(
        title: String,
        systemImage: String,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
        }
        .font(.whisperCaption)
        .foregroundStyle(isActive ? Color.whisperAccentText : Color.whisperTextSecondary)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(
            isActive ? Color.whisperSurfaceFocus : Color.whisperSurfaceSubtle,
            in: Capsule()
        )
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedEmotion != nil ||
            selectedCommitmentStatus != nil
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
    
    private var monthlyShelves: [(title: String, records: [WhisperRecord])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        let grouped = Dictionary(grouping: filteredRecords) {
            formatter.string(from: $0.createdAt)
        }
        return grouped
            .map { (title: $0.key, records: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.records.first!.createdAt > $1.records.first!.createdAt }
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
