//
//  JournalFlowViews.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct JournalFlowView: View {
    private enum Step: Hashable {
        case selection
        case generating
        case review
        case reflection
        case complete
    }

    let recordStore: RecordStore
    let date: Date
    private let isEditingExistingJournal: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.selection
    @State private var title: String
    @State private var bodyText: String
    @State private var reflection = ""
    @State private var emotion: String?
    @State private var orderedRecordIDs: [UUID]
    @State private var includedRecordIDs: Set<UUID>
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
            case .generating:
                JournalGeneratingStep {
                    step = .selection
                }
            case .review:
                JournalReviewStep(
                    date: date,
                    title: $title,
                    bodyText: $bodyText,
                    moments: includedOrderedMoments,
                    onBack: { step = .selection },
                    onAddReflection: { step = .reflection },
                    onSave: saveJournal
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
        .task(id: step) {
            guard step == .generating else { return }

            do {
                try await Task.sleep(
                    for: reduceMotion ? .milliseconds(120) : .milliseconds(700)
                )
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            step = .review
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

        step = isEditingExistingJournal ? .review : .generating
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

private struct JournalGeneratingStep: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: WhisperSpacing.large) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.whisperSurfaceHighlight)
                    .frame(width: 102, height: 102)

                Image.whisperFlame
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 48)
                    .accessibilityHidden(true)
            }

            VStack(spacing: WhisperSpacing.xSmall) {
                Text("오늘의 순간을 일기로 엮고 있어요")
                    .font(.whisperSheetTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .multilineTextAlignment(.center)

                Text("선택한 순간을 흐름대로 정리하고 있어요.")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .tint(Color.whisperAccent)
                .accessibilityLabel("일기 초안 만드는 중")

            Button("취소", action: onCancel)
                .font(.whisperControl)
                .foregroundStyle(Color.whisperAccentText)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("journal.cancelGenerationButton")

            Spacer()
            Spacer()
        }
        .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct JournalReviewStep: View {
    let date: Date
    @Binding var title: String
    @Binding var bodyText: String
    let moments: [WhisperRecord]
    let onBack: () -> Void
    let onAddReflection: () -> Void
    let onSave: () -> Void

    @State private var isEditingBody = false
    @State private var isSourcesPresented = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                    VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                        Text("\(date.whisperFullDayDescription) · \(moments.count)개의 순간")
                            .font(.whisperCaption)
                            .foregroundStyle(Color.whisperTextSecondary)

                        if isEditingBody {
                            TextField("일기 제목", text: $title, axis: .vertical)
                                .font(.whisperScreenTitle)
                                .foregroundStyle(Color.whisperTextPrimary)
                                .accessibilityIdentifier("journal.titleField")
                        } else {
                            Text(title)
                                .font(.whisperScreenTitle)
                                .foregroundStyle(Color.whisperTextPrimary)
                        }
                    }

                    Group {
                        if isEditingBody {
                            TextEditor(text: $bodyText)
                                .scrollContentBackground(.hidden)
                                .accessibilityIdentifier("journal.bodyField")
                        } else {
                            Text(bodyText)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .accessibilityIdentifier("journal.bodyPreview")
                        }
                    }
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .lineSpacing(7)
                    .frame(maxWidth: .infinity, minHeight: 248, alignment: .topLeading)
                    .padding(WhisperSpacing.medium)
                    .background(
                        Color.whisperSurfaceDefault,
                        in: RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
                    )

                    VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                        HStack {
                            Text("이 일기에 담긴 순간")
                                .font(.whisperSectionTitle)
                                .foregroundStyle(Color.whisperTextPrimary)

                            Spacer()

                            Button {
                                isSourcesPresented = true
                            } label: {
                                HStack(spacing: WhisperSpacing.xxSmall) {
                                    Text("\(moments.count)개 보기")
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .font(.whisperMetadata)
                            .foregroundStyle(Color.whisperAccentText)
                        }

                        JournalSourcePreview(moments: moments)
                    }

                    Button(action: onAddReflection) {
                        HStack(spacing: WhisperSpacing.small) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .foregroundStyle(Color.whisperAccentText)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                                Text("내 한 문장 더하기")
                                    .font(.whisperControl)
                                    .foregroundStyle(Color.whisperTextPrimary)

                                Text("선택 사항 · 이 화면에서 바로 추가할 수 있어요")
                                    .font(.whisperLabel)
                                    .foregroundStyle(Color.whisperTextSecondary)
                            }

                            Spacer(minLength: WhisperSpacing.xSmall)

                            ZStack {
                                Circle()
                                    .fill(Color.whisperSurfaceDefault.opacity(0.72))
                                    .frame(width: 58, height: 58)

                                Image.whisperFlame
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 36)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                        .padding(.leading, WhisperSpacing.medium)
                        .padding(.trailing, WhisperSpacing.xSmall)
                        .background(
                            Color.whisperSurfaceHighlight,
                            in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("journal.addReflectionButton")
                }
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.top, WhisperSpacing.small)
                .padding(.bottom, WhisperSpacing.xLarge)
            }
            .scrollIndicators(.hidden)

            Button("오늘의 일기로 저장", action: onSave)
                .buttonStyle(.whisperPrimary)
                .disabled(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    moments.isEmpty
                )
                .accessibilityIdentifier("journal.saveDraftButton")
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.bottom, WhisperSpacing.medium)
        }
        .navigationTitle("오늘의 일기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("순간 선택", systemImage: "chevron.left", action: onBack)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditingBody ? "수정 완료" : "본문 수정") {
                    isEditingBody.toggle()
                }
            }
        }
        .sheet(isPresented: $isSourcesPresented) {
            JournalSourcesSheet(records: moments)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(WhisperRadius.sheet)
        }
    }
}

private struct JournalSourcePreview: View {
    let moments: [WhisperRecord]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: WhisperSpacing.xSmall) {
                ForEach(moments) { moment in
                    Text(moment.createdAt.whisperTimeDescription)
                        .font(.whisperLabel)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .frame(width: 76, height: 40)
                        .background(
                            Color.whisperSurfaceDefault,
                            in: RoundedRectangle(cornerRadius: WhisperRadius.small, style: .continuous)
                        )
                }
            }
            .padding(WhisperSpacing.small)
        }
        .scrollIndicators(.hidden)
        .background(
            Color.whisperSurfaceHighlight,
            in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
        )
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
        ScrollView {
            VStack(spacing: WhisperSpacing.xLarge) {
                ZStack {
                    Circle()
                        .fill(Color.whisperSurfaceHighlight)
                        .frame(width: 112, height: 112)

                    Image.whisperFlame
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 48)
                        .accessibilityHidden(true)
                }

                VStack(spacing: WhisperSpacing.xSmall) {
                    Text("한 문장을 더할까요?")
                        .font(.whisperScreenTitle)
                        .foregroundStyle(Color.whisperTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("떠오를 때만 적어도 괜찮아요.\n건너뛰어도 일기는 저장돼요.")
                        .font(.whisperControl)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .multilineTextAlignment(.center)
                }

                reflectionField

                VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("오늘의 감정")
                            .font(.whisperSectionTitle)
                            .foregroundStyle(Color.whisperTextPrimary)

                        Spacer()

                        Text("선택 사항")
                            .font(.whisperLabel)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }

                    ScrollView(.horizontal) {
                        HStack(spacing: WhisperSpacing.xSmall) {
                            ForEach(emotions, id: \.self) { value in
                                emotionChip(value)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, WhisperSpacing.medium)
            .padding(.bottom, WhisperSpacing.xxLarge)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: WhisperSpacing.small) {
                Button("한 문장 추가하고 저장", action: onSave)
                    .buttonStyle(.whisperPrimary)
                    .disabled(trimmedReflection.isEmpty)
                    .accessibilityIdentifier("journal.saveButton")

                if trimmedReflection.isEmpty {
                    Button(
                        emotion == nil ? "한 문장 없이 저장" : "선택한 감정만 저장",
                        action: onSave
                    )
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("journal.skipReflectionButton")
                } else {
                    Text("저장한 뒤에도 언제든 다시 고칠 수 있어요")
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, WhisperSpacing.small)
            .background(Color.whisperBackground)
        }
        .navigationTitle("내 한 문장")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("일기 편집", systemImage: "chevron.left", action: onBack)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    isReflectionFocused = false
                }
            }
        }
    }

    private var trimmedReflection: String {
        reflection.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var reflectionField: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
            Text("나에게 남기는 말")
                .font(.whisperFieldLabel)
                .foregroundStyle(Color.whisperTextPrimary)

            ZStack(alignment: .topLeading) {
                if reflection.isEmpty {
                    Text("예: 서두르지 않아도 다시 시작할 수 있다.")
                        .font(.whisperBody)
                        .foregroundStyle(Color.whisperTextSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $reflection)
                    .focused($isReflectionFocused)
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 112)
                    .onChange(of: reflection) { _, newValue in
                        guard newValue.count > reflectionLimit else { return }
                        reflection = String(newValue.prefix(reflectionLimit))
                    }
                    .accessibilityIdentifier("journal.reflectionField")
            }

            Divider()

            HStack {
                Text("한 문장으로 짧게 남겨도 충분해요")
                Spacer()
                Text("\(reflection.count) / \(reflectionLimit)")
            }
            .font(.whisperLabel)
            .foregroundStyle(Color.whisperTextSecondary)
        }
        .padding(WhisperSpacing.medium)
        .background(
            Color.whisperSurfaceDefault,
            in: RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
                .stroke(
                    isReflectionFocused ? Color.whisperAccent : Color.whisperBorderSubtle,
                    lineWidth: 1
                )
        }
    }

    private func emotionChip(_ value: String) -> some View {
        Button {
            emotion = emotion == value ? nil : value
        } label: {
            WhisperFilterChip(
                title: value,
                isSelected: emotion == value
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(emotion == value ? .isSelected : [])
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

                if !journal.reflection.isEmpty || journal.emotion != nil {
                    HStack(alignment: .bottom, spacing: WhisperSpacing.small) {
                        Image.whisperFlame
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 48)
                        VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                            HStack {
                                Text("오늘의 의미")
                                    .font(.whisperLabel)
                                    .foregroundStyle(Color.whisperAccentText)

                                if let emotion = journal.emotion {
                                    Text(emotion)
                                        .font(.whisperLabel)
                                        .foregroundStyle(Color.whisperTextPrimary)
                                        .padding(.horizontal, WhisperSpacing.xSmall)
                                        .padding(.vertical, WhisperSpacing.xxSmall)
                                        .background(Color.whisperSurfaceDefault, in: Capsule())
                                }
                            }

                            if !journal.reflection.isEmpty {
                                Text(journal.reflection)
                                    .font(.whisperBody)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(WhisperSpacing.large)
                    .background(
                        Color.whisperSurfaceHighlight,
                        in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                    )
                }

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

private struct JournalSourcesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let records: [WhisperRecord]

    var body: some View {
        NavigationStack {
            JournalSourcesView(records: records)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("닫기")
                }
            }
        }
    }
}

private extension Color {
    static let whisperColorDark = Color(red: 0.11, green: 0.13, blue: 0.12)
}

#Preview("Journal Library") {
    NavigationStack {
        JournalLibraryView(recordStore: RecordStore(isStoredInMemoryOnly: true))
    }
}
