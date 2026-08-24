//
//  RecordFlowViews.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

enum EmberJarSize {
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

struct EmberJar: View {
    let size: EmberJarSize
    
    var body: some View {
        Image("Ember")
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
    @State private var selectedFocus: String?
    @State private var photoData: Data?
    @State private var isSaved = false
    @State private var isEmotionPickerPresented = false
    let onSave: (String?, String?, Data?) -> Void
    private let contentLimit = 1_000
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Date.now.emberFullDayDescription)
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
                    .padding(.top, 12)
                fieldLabel("제목")
                TextField("오늘의 마음에 제목을 붙여주세요", text: $draft.title)
                    .font(.emberBodyLarge)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.emberSurfaceSubtle, in: RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous))
                
                fieldLabel("기록")
                ZStack(alignment: .bottomTrailing) {
                    TextField("오늘 있었던 일과 생각을 천천히 적어보세요", text: $draft.content, axis: .vertical)
                        .font(.emberBodyLarge)
                        .lineSpacing(5)
                        .lineLimit(6 ... 8)
                        .padding(18)
                        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
                        .onChange(of: draft.content) { _, newValue in
                            guard newValue.count > contentLimit else { return }
                            draft.content = String(newValue.prefix(contentLimit))
                        }
                    Text("\(draft.content.count) / \(contentLimit.formatted())")
                        .font(.emberCaption)
                        .foregroundStyle(Color.emberTextSecondary)
                        .padding(16)
                }
                .background(Color.emberSurfaceSubtle, in: RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous))
                
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
                
                NavigationLink {
                    FocusModePicker(selectedFocus: $selectedFocus)
                } label: {
                    HStack(spacing: 16) {
                        EmberJar(size: .small)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selectedFocus ?? "FocusMode 선택")
                                .font(.emberBodyEmphasis)
                                .foregroundStyle(Color.emberTextPrimary)
                            Text("기록을 FocusMode와 연결해요").font(.emberMetadata).foregroundStyle(Color.emberTextSecondary)
                        }
                        Spacer()
                        Text(selectedFocus == nil ? "선택" : "연결됨")
                            .font(.emberCaption)
                            .foregroundStyle(Color.emberAccentText)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 96)
                    .background(Color.emberSurfaceFocus, in: RoundedRectangle(cornerRadius: EmberRadius.large, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Label("FocusMode가 시작되면 이 기록을 알림으로 다시 만나요.", systemImage: "bell")
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberTextSecondary)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(Color.emberSurfaceSubtle, in: RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous))
            }
            .padding(.horizontal, EmberLayout.screenHorizontalPadding)
            .padding(.bottom, 90)
        }
        .scrollIndicators(.hidden)
        .background(Color.emberBackground)
        .safeAreaInset(edge: .bottom) {
            Button("기록 저장") {
                onSave(selectedFocus, selectedEmotion, photoData)
                isSaved = true
            }
            .buttonStyle(.emberPrimary)
            .disabled(!draft.canSave)
            .padding(.horizontal, EmberLayout.screenHorizontalPadding)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("상세 기록")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isSaved) {
            SavedRecordSheet(focusMode: selectedFocus) {
                dismiss()
            }
            .presentationDetents([.height(312)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isEmotionPickerPresented) {
            EmotionPickerView(selectedEmotion: $selectedEmotion)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }
    
    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.emberFieldLabel).foregroundStyle(Color.emberTextPrimary)
    }
    
    private func recordChip(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.emberControl)
                .foregroundStyle(Color.emberTextPrimary)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Color.emberSurfaceSubtle, in: RoundedRectangle(cornerRadius: EmberRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SavedRecordSheet: View {
    let focusMode: String?
    let onHome: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Text("오늘의 불꽃을 담았어요")
                .font(.emberNavigationTitle)
                .foregroundStyle(Color.emberTextPrimary)
            Text(savedDescription)
                .font(.emberBody)
                .foregroundStyle(Color.emberTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            EmberJar(size: .hero).padding(.vertical, 4)
            Button("홈으로 돌아가기", action: onHome)
                .buttonStyle(.emberPrimary(size: .compact))
                .padding(.top, 2)
        }
        .padding(.horizontal, EmberLayout.sheetHorizontalPadding)
        .padding(.top, 10)
        .background(Color.emberSurfaceDefault)
    }

    private var savedDescription: String {
        guard let focusMode else {
            return "기록은 보관함에서\n언제든 다시 꺼내볼 수 있어요."
        }
        return "\(focusMode)가 시작되면\n이 기록을 다시 알려드릴게요."
    }
}

struct FocusModePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFocus: String?
    private let modes = ["업무 집중 모드", "운동", "독서"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FocusMode 연결")
                .font(.emberScreenTitle)
                .padding(.top, 12)
            Text("이 기록을 다시 만날 FocusMode를 선택해요.")
                .font(.emberBody)
                .foregroundStyle(Color.emberTextSecondary)
            Button {
                selectedFocus = nil
                dismiss()
            } label: {
                focusModeRow(title: "연결 안 함", isSelected: selectedFocus == nil)
            }
            .buttonStyle(.plain)

            ForEach(modes, id: \.self) { mode in
                Button {
                    selectedFocus = mode
                    dismiss()
                } label: {
                    focusModeRow(title: mode, isSelected: selectedFocus == mode)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, EmberLayout.screenHorizontalPadding)
        .background(Color.emberBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func focusModeRow(title: String, isSelected: Bool) -> some View {
        HStack(spacing: 16) {
            EmberJar(size: .small)
            Text(title).font(.emberBodyEmphasis).foregroundStyle(Color.emberTextPrimary)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.emberAccent : Color.emberTextSecondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 84)
        .background(Color.emberSurfaceDefault, in: RoundedRectangle(cornerRadius: EmberRadius.large, style: .continuous))
    }
}

struct CollectionView: View {
    let recordStore: RecordStore
    @State private var searchText = ""
    @State private var selectedFocus: String?
    @State private var selectedEmotion: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("불꽃 보관함")
                .font(.emberScreenTitle)
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
                        Text(shelf.title).font(.emberSectionTitle)
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
                                        EmberJar(size: .shelf)

                                        if record.photoData != nil {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Color.white)
                                                .frame(width: 20, height: 20)
                                                .background(Color.emberAccent, in: Circle())
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    "\(record.title), \(record.createdAt.emberFullDayDescription)"
                                )
                            }
                        }
                        Rectangle().fill(Color.emberDivider).frame(height: 1)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
        .scrollIndicators(.hidden)
        .background(Color.emberBackground)
        .navigationBarHidden(true)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.emberTextSecondary)

            TextField("제목이나 내용 검색", text: $searchText)
                .font(.emberBody)
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.emberTextSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            Color.emberSurfaceSubtle,
            in: RoundedRectangle(
                cornerRadius: EmberRadius.medium,
                style: .continuous
            )
        )
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Menu {
                    Button("전체 FocusMode") { selectedFocus = nil }
                    ForEach(EmberFocusMode.allCases, id: \.self) { mode in
                        Button(mode.rawValue) { selectedFocus = mode.rawValue }
                    }
                } label: {
                    filterChip(
                        title: selectedFocus ?? "FocusMode",
                        systemImage: "moon.stars",
                        isActive: selectedFocus != nil
                    )
                }

                Menu {
                    Button("전체 감정") { selectedEmotion = nil }
                    ForEach(EmberEmotion.allCases) { emotion in
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

                if hasActiveFilters {
                    Button("초기화", action: resetFilters)
                        .font(.emberCaption)
                        .foregroundStyle(Color.emberAccentText)
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
        .font(.emberCaption)
        .foregroundStyle(isActive ? Color.emberAccentText : Color.emberTextSecondary)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(
            isActive ? Color.emberSurfaceFocus : Color.emberSurfaceSubtle,
            in: Capsule()
        )
    }

    private var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            selectedFocus != nil ||
            selectedEmotion != nil
    }

    private var filteredRecords: [EmberRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return recordStore.records.filter { record in
            let matchesSearch = query.isEmpty ||
                record.title.localizedCaseInsensitiveContains(query) ||
                record.content.localizedCaseInsensitiveContains(query)
            let matchesFocus = selectedFocus == nil || record.focusMode == selectedFocus
            let matchesEmotion = selectedEmotion == nil || record.emotion == selectedEmotion
            return matchesSearch && matchesFocus && matchesEmotion
        }
    }

    private func resetFilters() {
        searchText = ""
        selectedFocus = nil
        selectedEmotion = nil
    }
    
    private var monthlyShelves: [(title: String, records: [EmberRecord])] {
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

struct FocusConnectionsView: View {
    let recordStore: RecordStore
    @State private var selectedFocus = "업무 집중 모드"
    @State private var isPersistenceErrorPresented = false
    private let modes = ["업무 집중 모드", "운동", "독서"]
    
    var body: some View {
        List {
            Section {
                Text("필요한 기록을 직접 골라 연결해요. 모드가 시작되면 알림으로 다시 만나요.")
                    .font(.emberBody)
                    .foregroundStyle(Color.emberTextSecondary)
                    .listRowBackground(Color.clear)

                Picker("FocusMode", selection: $selectedFocus) {
                    ForEach(modes, id: \.self) { mode in
                        Text("\(mode) · \(recordStore.records(linkedTo: mode).count)")
                            .tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("이 모드에서 다시 만날 기록") {
                if recordStore.records.isEmpty {
                    Text("연결할 기록이 아직 없어요.")
                        .font(.emberBody)
                        .foregroundStyle(Color.emberTextSecondary)
                } else {
                    ForEach(recordStore.records) { record in
                        Button {
                            toggleConnection(for: record)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                EmberJar(size: .small)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.title).font(.emberBodyEmphasis).foregroundStyle(Color.emberTextPrimary)
                                    Text(record.content).font(.emberMetadata).foregroundStyle(Color.emberTextSecondary).lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: isConnected(record) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isConnected(record) ? Color.emberAccent : Color.emberTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.emberBackground)
        .navigationTitle("FocusMode 연결")
        .navigationBarTitleDisplayMode(.inline)
        .alert("연결을 저장할 수 없어요", isPresented: $isPersistenceErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("잠시 후 다시 시도해 주세요.")
        }
    }

    private func isConnected(_ record: EmberRecord) -> Bool {
        record.focusMode == selectedFocus
    }

    private func toggleConnection(for record: EmberRecord) {
        let focusMode = isConnected(record) ? nil : selectedFocus
        if !recordStore.setFocusMode(focusMode, for: record) {
            isPersistenceErrorPresented = true
        }
    }
}

private struct DetailedRecordPreview: View {
    @State private var draft = RecordDraft()

    var body: some View {
        NavigationStack {
            DetailedRecordView(draft: $draft, onSave: { _, _, _ in })
        }
    }
}

#Preview { DetailedRecordPreview() }

#Preview {
    CollectionView(recordStore: RecordStore(isStoredInMemoryOnly: true))
}
