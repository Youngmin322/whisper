//
//  JournalFlowViews.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct JournalFlowView: View {
    private enum Step {
        case selection
        case review
        case reflection
        case complete
    }

    let recordStore: RecordStore
    let date: Date
    private let isEditingExistingJournal: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.selection
    @State private var title: String
    @State private var bodyText: String
    @State private var reflection = ""
    @State private var emotion: String?
    @State private var orderedRecordIDs: [UUID]
    @State private var includedRecordIDs: Set<UUID>
    @State private var isPreviewPresented = false
    @State private var isSaveErrorPresented = false

    init(recordStore: RecordStore, date: Date = .now) {
        self.recordStore = recordStore
        self.date = date

        let existing = recordStore.journal(on: date)
        let draft = recordStore.journalDraft(on: date)
        let includedSourceIDs = existing?.sourceRecordIDs ?? draft.sourceRecordIDs
        let remainingSourceIDs = draft.sourceRecordIDs.filter { !includedSourceIDs.contains($0) }
        let orderedSourceIDs = includedSourceIDs + remainingSourceIDs
        isEditingExistingJournal = existing != nil
        _title = State(initialValue: existing?.title ?? draft.title)
        _bodyText = State(initialValue: existing?.body ?? draft.body)
        _reflection = State(initialValue: existing?.reflection ?? "")
        _emotion = State(initialValue: existing?.emotion)
        _orderedRecordIDs = State(initialValue: orderedSourceIDs)
        _includedRecordIDs = State(initialValue: Set(includedSourceIDs))
    }

    var body: some View {
        Group {
            switch step {
            case .selection:
                JournalSelectionStep(
                    moments: orderedMoments,
                    includedRecordIDs: $includedRecordIDs,
                    onMove: moveMoments,
                    onNext: prepareDraftForReview
                )
            case .review:
                JournalReviewStep(
                    date: date,
                    title: $title,
                    bodyText: $bodyText,
                    moments: includedOrderedMoments,
                    onCancel: { step = .selection },
                    onPreview: { isPreviewPresented = true },
                    onNext: { step = .reflection }
                )
            case .reflection:
                JournalReflectionStep(
                    reflection: $reflection,
                    emotion: $emotion,
                    onBack: { step = .review },
                    onSave: saveJournal
                )
            case .complete:
                if let journal = recordStore.journal(on: date) {
                    JournalCompletionStep(
                        journal: journal,
                        sourceRecords: sourceRecords(for: journal),
                        onEdit: { step = .review },
                        onClose: { dismiss() }
                    )
                }
            }
        }
        .background(Color.whisperBackground.ignoresSafeArea())
        .sheet(isPresented: $isPreviewPresented) {
            JournalDraftPreview(
                date: date,
                title: title,
                bodyText: bodyText,
                reflection: reflection
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(WhisperRadius.sheet)
        }
        .alert("일기를 저장할 수 없어요", isPresented: $isSaveErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("작성한 내용은 그대로 두었어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    private var orderedMoments: [WhisperRecord] {
        orderedRecordIDs.compactMap(recordStore.record(withID:))
    }

    private var includedOrderedMoments: [WhisperRecord] {
        orderedMoments.filter { includedRecordIDs.contains($0.id) }
    }

    private func moveMoments(from source: IndexSet, to destination: Int) {
        orderedRecordIDs.move(fromOffsets: source, toOffset: destination)
    }

    private func prepareDraftForReview() {
        guard !includedOrderedMoments.isEmpty else { return }

        if !isEditingExistingJournal {
            title = "\(includedOrderedMoments.count)개의 순간이 이어진 하루"
            bodyText = includedOrderedMoments
                .map(\.content)
                .joined(separator: "\n\n")
        }

        step = .review
    }

    private func saveJournal() {
        let sourceIDs = orderedRecordIDs.filter(includedRecordIDs.contains)
        guard recordStore.saveJournal(
            on: date,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            reflection: reflection.trimmingCharacters(in: .whitespacesAndNewlines),
            emotion: emotion,
            sourceRecordIDs: sourceIDs
        ) != nil else {
            isSaveErrorPresented = true
            return
        }
        step = .complete
    }

    private func sourceRecords(for journal: DailyJournal) -> [WhisperRecord] {
        journal.sourceRecordIDs.compactMap(recordStore.record(withID:))
    }
}

private struct JournalSelectionStep: View {
    let moments: [WhisperRecord]
    @Binding var includedRecordIDs: Set<UUID>
    let onMove: (IndexSet, Int) -> Void
    let onNext: () -> Void

    private var selectedCount: Int {
        includedRecordIDs.count
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text("일기에 담을 순간을 정해주세요")
                    .font(.whisperScreenTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("체크로 포함 여부를, 오른쪽 핸들로 흐름을 바꿀 수 있어요.")
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("오늘의 순간")
                        .font(.whisperSectionTitle)
                        .foregroundStyle(Color.whisperTextPrimary)

                    Spacer()

                    Text("\(selectedCount)개 선택됨")
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperAccentText)
                        .padding(.horizontal, WhisperSpacing.medium)
                        .frame(minHeight: 34)
                        .background(Color.whisperSurfaceHighlight, in: Capsule())
                        .accessibilityLabel("\(selectedCount)개 선택됨")
                }
                .padding(.top, WhisperSpacing.medium)
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, WhisperSpacing.small)
            .padding(.bottom, WhisperSpacing.small)

            List {
                ForEach(moments) { moment in
                    JournalMomentSelectionRow(
                        moment: moment,
                        isIncluded: includedRecordIDs.contains(moment.id),
                        onToggle: { toggle(moment.id) }
                    )
                    .listRowInsets(
                        EdgeInsets(
                            top: WhisperSpacing.xSmall,
                            leading: WhisperLayout.screenHorizontalPadding,
                            bottom: WhisperSpacing.xSmall,
                            trailing: WhisperLayout.screenHorizontalPadding
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: onMove)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))

            Text("체크를 끄면 원본 순간은 남고 일기에서만 제외돼요")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WhisperLayout.sheetHorizontalPadding + WhisperSpacing.medium)
                .padding(.top, WhisperSpacing.xSmall)

            Button(action: onNext) {
                Text("\(selectedCount)개의 순간으로 초안 만들기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.whisperPrimary)
            .disabled(selectedCount == 0)
            .accessibilityIdentifier("journal.createDraftButton")
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, WhisperSpacing.xLarge)
            .padding(.bottom, WhisperSpacing.medium)
        }
        .navigationTitle("오늘 마무리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func toggle(_ id: UUID) {
        if includedRecordIDs.contains(id) {
            includedRecordIDs.remove(id)
        } else {
            includedRecordIDs.insert(id)
        }
    }
}

private struct JournalReviewStep: View {
    let date: Date
    @Binding var title: String
    @Binding var bodyText: String
    let moments: [WhisperRecord]
    let onCancel: () -> Void
    let onPreview: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            journalHeader(
                leading: "‹ 순간 선택",
                title: "일기 초안",
                trailing: "미리보기",
                onLeading: onCancel,
                onTrailing: onPreview
            )

            ScrollView {
                VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                    VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                        Text("\(date.whisperDayDescription) · \(moments.count)개의 순간")
                            .font(.whisperLabel)
                            .foregroundStyle(Color.whisperTextSecondary)

                        TextField("일기 제목", text: $title, axis: .vertical)
                            .font(.whisperScreenTitle)
                            .foregroundStyle(Color.whisperTextPrimary)
                            .accessibilityIdentifier("journal.titleField")
                    }

                    JournalMomentStrip(moments: moments)

                    VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                        TextEditor(text: $bodyText)
                            .font(.whisperBody)
                            .lineSpacing(6)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 156)
                            .accessibilityIdentifier("journal.bodyField")

                        Text("초안을 눌러 직접 고칠 수 있어요")
                            .font(.whisperLabel)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }
                    .padding(WhisperSpacing.medium)
                    .background(
                        Color.whisperSurfaceSubtle,
                        in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                            .stroke(Color.whisperBorderSubtle, lineWidth: 1)
                    }

                }
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.bottom, WhisperSpacing.large)
            }
            .scrollIndicators(.hidden)

            Button("다음 · 내 한 문장", action: onNext)
                .buttonStyle(.whisperPrimary)
                .disabled(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    moments.isEmpty
                )
                .accessibilityIdentifier("journal.nextButton")
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.bottom, WhisperSpacing.medium)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct JournalMomentStrip: View {
    let moments: [WhisperRecord]

    var body: some View {
        HStack(spacing: WhisperSpacing.small) {
            ForEach(Array(moments.prefix(3))) { moment in
                Group {
                    if let photoData = moment.photoData,
                       let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(Color.whisperAccent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.whisperSurfaceHighlight)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .clipShape(RoundedRectangle(cornerRadius: WhisperRadius.small, style: .continuous))
            }
        }
    }
}

private struct JournalMomentSelectionRow: View {
    let moment: WhisperRecord
    let isIncluded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: WhisperSpacing.small) {
            Button(action: onToggle) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isIncluded ? Color.whisperAccent : Color.whisperTextSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isIncluded ? "순간 제외" : "순간 포함")

            VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                Text("\(moment.createdAt.whisperTimeDescription) · \(moment.photoData == nil ? "텍스트" : "사진")")
                    .font(.whisperLabel)
                    .foregroundStyle(Color.whisperTextSecondary)

                Text(moment.content)
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(minHeight: 68)
        .padding(.horizontal, WhisperSpacing.small)
        .padding(.vertical, WhisperSpacing.xSmall)
        .background(
            Color.whisperSurfaceDefault,
            in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                .stroke(Color.whisperBorderSubtle, lineWidth: 1)
        }
        .opacity(isIncluded ? 1 : 0.62)
    }
}

private struct JournalReflectionStep: View {
    @Binding var reflection: String
    @Binding var emotion: String?
    let onBack: () -> Void
    let onSave: () -> Void

    @FocusState private var isReflectionFocused: Bool
    private let reflectionLimit = 120
    private let emotions = ["차분함", "기쁨", "아쉬움"]

    var body: some View {
        VStack(spacing: 0) {
            journalHeader(
                leading: "‹ 이전",
                title: "오늘의 의미",
                onLeading: onBack
            )

            ScrollView {
                VStack(spacing: WhisperSpacing.large) {
                    ZStack {
                        Circle()
                            .fill(Color.whisperSurfaceHighlight)
                            .frame(width: 154, height: 154)
                        Image.whisperFlame
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 62)
                    }

                    VStack(spacing: WhisperSpacing.xSmall) {
                        Text("오늘, 오래 남기고 싶은 건?")
                            .font(.whisperScreenTitle)
                            .multilineTextAlignment(.center)
                        Text("정답 대신 당신의 한 문장을 더해주세요.")
                            .font(.whisperControl)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }

                    VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                        TextEditor(text: $reflection)
                            .focused($isReflectionFocused)
                            .font(.whisperBody)
                            .lineSpacing(5)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100)
                            .onChange(of: reflection) { _, newValue in
                                guard newValue.count > reflectionLimit else { return }
                                reflection = String(newValue.prefix(reflectionLimit))
                            }
                            .accessibilityIdentifier("journal.reflectionField")

                        Divider()
                        Text("\(reflection.count) / \(reflectionLimit)")
                            .font(.whisperLabel)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }
                    .padding(WhisperSpacing.medium)
                    .background(
                        Color.whisperSurfaceHighlight.opacity(0.52),
                        in: RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
                            .stroke(Color.whisperAccent.opacity(0.5), lineWidth: 1)
                    }

                    HStack(spacing: WhisperSpacing.xSmall) {
                        suggestionChip("🙂 평온했어요")
                        suggestionChip("🌿 가벼움")
                        suggestionChip("＋ 감정 더하기")
                    }

                    HStack(spacing: WhisperSpacing.xSmall) {
                        ForEach(emotions, id: \.self) { value in
                            emotionChip(value)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.bottom, WhisperSpacing.large)
            }
            .scrollIndicators(.hidden)

            Button("오늘 일기로 남기기", action: onSave)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 25))
                .controlSize(.large)
                .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("journal.saveButton")
                .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)

            Text("언제든 다시 고칠 수 있어요")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .padding(.vertical, WhisperSpacing.medium)
        }
        .task {
            await Task.yield()
            isReflectionFocused = reflection.isEmpty
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func suggestionChip(_ value: String) -> some View {
        Button(value) {
            if reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               value != "＋ 감정 더하기" {
                reflection = value.replacingOccurrences(of: "🙂 ", with: "")
                    .replacingOccurrences(of: "🌿 ", with: "")
            } else {
                isReflectionFocused = true
            }
        }
        .font(.whisperCaption)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(Color.whisperTextSecondary)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func emotionChip(_ value: String) -> some View {
        if emotion == value {
            Button(value) { emotion = nil }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        } else {
            Button(value) { emotion = value }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
}

struct JournalLibraryView: View {
    let recordStore: RecordStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                Text("일기")
                    .font(.whisperScreenTitle)

                if shouldShowTodayDraft {
                    NavigationLink {
                        JournalFlowView(recordStore: recordStore)
                    } label: {
                        readyCard
                    }
                    .buttonStyle(.plain)
                }

                if recordStore.journals.isEmpty {
                    ContentUnavailableView(
                        "아직 완성한 일기가 없어요",
                        systemImage: "book.closed",
                        description: Text("오늘의 순간을 남기면 하루 초안을 만들 수 있어요.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    LazyVStack(spacing: WhisperSpacing.small) {
                        ForEach(recordStore.journals.sorted { $0.date > $1.date }) { journal in
                            NavigationLink {
                                JournalDetailView(journal: journal, recordStore: recordStore)
                            } label: {
                                journalCard(journal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, WhisperSpacing.small)
            .padding(.bottom, WhisperSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .background(Color.whisperBackground)
        .navigationBarHidden(true)
    }

    private var shouldShowTodayDraft: Bool {
        !recordStore.journalDraft().isEmpty && recordStore.journal(on: .now) == nil
    }

    private var readyCard: some View {
        HStack(spacing: WhisperSpacing.medium) {
            WhisperJarAnimation(size: .home)
            VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                Text("오늘의 초안이 준비됐어요")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperAccent)
                Text("30초만 검토하면\n오늘이 일기가 돼요")
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextOnAccent)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.white.opacity(0.8))
        }
        .padding(WhisperSpacing.large)
        .background(
            LinearGradient(
                colors: [Color.whisperColorDark, Color.whisperColorDark.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
        )
    }

    private func journalCard(_ journal: DailyJournal) -> some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            Text(journal.date.whisperFullDayDescription)
                .font(.whisperLabel)
                .foregroundStyle(Color.whisperTextSecondary)
            Text(journal.title)
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperTextPrimary)
            Text(journal.body)
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
                .lineLimit(3)
            Label("\(journal.sourceRecordIDs.count)개의 순간", systemImage: "flame.fill")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperAccentText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WhisperSpacing.large)
        .background(
            Color.whisperSurfaceSubtle,
            in: RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
        )
    }
}

struct JournalDetailView: View {
    let journal: DailyJournal
    let recordStore: RecordStore

    var body: some View {
        JournalDetailContent(
            journal: journal,
            sourceRecords: journal.sourceRecordIDs.compactMap(recordStore.record(withID:))
        )
        .navigationTitle("일기")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct JournalCompletionStep: View {
    let journal: DailyJournal
    let sourceRecords: [WhisperRecord]
    let onEdit: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("‹ 일기", action: onClose)
                Spacer()
                Button("수정", action: onEdit)
            }
            .font(.whisperControl)
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding - 4)

            JournalDetailContent(journal: journal, sourceRecords: sourceRecords)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct JournalDetailContent: View {
    let journal: DailyJournal
    let sourceRecords: [WhisperRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                    Text(journal.date.whisperFullDayDescription)
                        .font(.whisperLabel)
                        .foregroundStyle(Color.whisperTextSecondary)
                    Text(journal.title)
                        .font(.whisperScreenTitle)
                }

                JournalLandscapeArtwork()

                Text(journal.body)
                    .font(.whisperBody)
                    .lineSpacing(8)

                HStack(alignment: .bottom, spacing: WhisperSpacing.small) {
                    Image.whisperFlame
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 48)
                    VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                        Text("내가 더한 한 문장")
                            .font(.whisperLabel)
                            .foregroundStyle(Color.whisperAccentText)
                        Text(journal.reflection)
                            .font(.whisperBody)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WhisperSpacing.large)
                .background(
                    Color.whisperSurfaceHighlight,
                    in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                )

                NavigationLink {
                    JournalSourcesView(records: sourceRecords)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                            Text("이 일기의 재료")
                                .font(.whisperCaption)
                                .foregroundStyle(Color.whisperTextSecondary)
                            Text("\(sourceRecords.count)개의 순간 보기")
                                .font(.whisperBody)
                                .foregroundStyle(Color.whisperTextPrimary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.whisperTextPrimary)
                    }
                    .padding(WhisperSpacing.medium)
                    .background(
                        Color.whisperSurfaceSubtle,
                        in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.bottom, WhisperSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .background(Color.whisperBackground)
    }
}

private struct JournalLandscapeArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color(red: 0.83, green: 0.89, blue: 0.86)
                Circle()
                    .fill(Color(red: 0.98, green: 0.78, blue: 0.60))
                    .frame(width: 62, height: 62)
                    .position(x: geometry.size.width * 0.8, y: 52)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.28, y: 82))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.51, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.58, green: 0.72, blue: 0.66))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.28, y: 128))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.52, y: geometry.size.height - 12))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.75, y: 105))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(Color(red: 0.42, green: 0.62, blue: 0.55))
            }
        }
        .frame(height: 206)
        .clipShape(RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct JournalSourcesView: View {
    let records: [WhisperRecord]

    var body: some View {
        List(records) { record in
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text(record.content)
                    .font(.whisperBody)
                Text(record.createdAt.whisperTimeDescription)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
            .padding(.vertical, WhisperSpacing.xSmall)
        }
        .navigationTitle("일기의 순간")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct JournalDraftPreview: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let title: String
    let bodyText: String
    let reflection: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                    Text(date.whisperFullDayDescription)
                        .font(.whisperLabel)
                        .foregroundStyle(Color.whisperTextSecondary)
                    Text(title)
                        .font(.whisperScreenTitle)
                    JournalLandscapeArtwork()
                    Text(bodyText)
                        .font(.whisperBody)
                        .lineSpacing(8)
                    if !reflection.isEmpty {
                        Text(reflection)
                            .font(.whisperBodyEmphasis)
                            .padding(WhisperSpacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.whisperSurfaceHighlight, in: RoundedRectangle(cornerRadius: WhisperRadius.large))
                    }
                }
                .padding(WhisperLayout.screenHorizontalPadding)
            }
            .navigationTitle("미리보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}

private func journalHeader(
    leading: String,
    title: String,
    trailing: String? = nil,
    onLeading: @escaping () -> Void,
    onTrailing: @escaping () -> Void = {}
) -> some View {
    ZStack {
        Text(title)
            .font(.whisperNavigationTitle)
        HStack {
            Button(leading, action: onLeading)
                .foregroundStyle(Color.whisperTextSecondary)
            Spacer()
            if let trailing {
                Button(trailing, action: onTrailing)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperAccentText)
            }
        }
    }
    .frame(height: 52)
    .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
}

private extension Color {
    static let whisperColorDark = Color(red: 0.11, green: 0.13, blue: 0.12)
}

#Preview("Journal Library") {
    NavigationStack {
        JournalLibraryView(recordStore: RecordStore(isStoredInMemoryOnly: true))
    }
}
