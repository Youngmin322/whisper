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
    @State private var selectedEmotion = "평온"
    @State private var selectedFocus = "업무 집중 모드"
    @State private var isSaved = false
    let onSave: () -> Void
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
                    recordChip(icon: "face.smiling", title: selectedEmotion)
                    recordChip(icon: "photo", title: "사진")
                }
                
                NavigationLink {
                    FocusModePicker(selectedFocus: $selectedFocus)
                } label: {
                    HStack(spacing: 16) {
                        EmberJar(size: .small)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selectedFocus).font(.emberBodyEmphasis).foregroundStyle(Color.emberTextPrimary)
                            Text("기록을 FocusMode와 연결해요").font(.emberMetadata).foregroundStyle(Color.emberTextSecondary)
                        }
                        Spacer()
                        Text("연결됨").font(.emberCaption).foregroundStyle(Color.emberAccentText)
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
                onSave()
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
            SavedRecordSheet {
                dismiss()
            }
            .presentationDetents([.height(312)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }
    
    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.emberFieldLabel).foregroundStyle(Color.emberTextPrimary)
    }
    
    private func recordChip(icon: String, title: String) -> some View {
        Button {} label: {
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
    let onHome: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Text("오늘의 불꽃을 담았어요")
                .font(.emberNavigationTitle)
                .foregroundStyle(Color.emberTextPrimary)
            Text("업무 집중 모드가 시작되면\n이 기록을 다시 알려드릴게요.")
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
}

struct FocusModePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFocus: String
    private let modes = ["업무 집중 모드", "운동", "독서"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FocusMode 연결")
                .font(.emberScreenTitle)
                .padding(.top, 12)
            Text("이 기록을 다시 만날 FocusMode를 선택해요.")
                .font(.emberBody)
                .foregroundStyle(Color.emberTextSecondary)
            ForEach(modes, id: \.self) { mode in
                Button {
                    selectedFocus = mode
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        EmberJar(size: .small)
                        Text(mode).font(.emberBodyEmphasis).foregroundStyle(Color.emberTextPrimary)
                        Spacer()
                        Image(systemName: selectedFocus == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedFocus == mode ? Color.emberAccent : Color.emberTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 84)
                    .background(Color.emberSurfaceDefault, in: RoundedRectangle(cornerRadius: EmberRadius.large, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, EmberLayout.screenHorizontalPadding)
        .background(Color.emberBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CollectionView: View {
    let recordStore: RecordStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("불꽃 보관함")
                .font(.emberScreenTitle)
                .padding(.top, 18)
            
            ScrollView {
                
                if recordStore.records.isEmpty {
                    ContentUnavailableView(
                        "아직 담긴 불꽃이 없어요",
                        systemImage: "flame",
                        description: Text("오늘의 마음을 기록하면 이곳에 하나씩 쌓여요.")
                    )
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
                            ForEach(shelf.records) { _ in
                                EmberJar(size: .shelf)
                                    .frame(maxWidth: .infinity)
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
    
    private var monthlyShelves: [(title: String, records: [EmberRecord])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        let grouped = Dictionary(grouping: recordStore.records) { formatter.string(from: $0.createdAt) }
        return grouped
            .map { (title: $0.key, records: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.records.first!.createdAt > $1.records.first!.createdAt }
    }
}

struct FocusConnectionsView: View {
    @State private var enabled = Set(["결심"])
    private let records = [
        ("결심", "이번 주에는 기초를 단단히 익히자."),
        ("마음가짐", "조급해하지 말고 한 가지에 집중하기."),
        ("동기", "내가 만든 작은 변화도 충분히 의미 있다.")
    ]
    
    var body: some View {
        List {
            Section {
                Text("필요한 기록을 직접 골라 연결해요. 모드가 시작되면 알림으로 다시 만나요.")
                    .font(.emberBody)
                    .foregroundStyle(Color.emberTextSecondary)
                    .listRowBackground(Color.clear)
            }
            Section("이 모드에서 다시 만날 기록") {
                ForEach(records, id: \.0) { record in
                    Button {
                        if enabled.contains(record.0) { enabled.remove(record.0) } else { enabled.insert(record.0) }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            EmberJar(size: .small)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.0).font(.emberBodyEmphasis).foregroundStyle(Color.emberTextPrimary)
                                Text(record.1).font(.emberMetadata).foregroundStyle(Color.emberTextSecondary)
                            }
                            Spacer()
                            Image(systemName: enabled.contains(record.0) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(enabled.contains(record.0) ? Color.emberAccent : Color.emberTextSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.emberBackground)
        .navigationTitle("업무 집중 모드")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailedRecordPreview: View {
    @State private var draft = RecordDraft()

    var body: some View {
        NavigationStack {
            DetailedRecordView(draft: $draft, onSave: {})
        }
    }
}

#Preview { DetailedRecordPreview() }

#Preview {
    CollectionView(recordStore: RecordStore(isStoredInMemoryOnly: true))
}
