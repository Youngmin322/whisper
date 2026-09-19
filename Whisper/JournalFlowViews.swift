//
//  JournalFlowViews.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct JournalFlowView: View {
    private enum Step {
        case review
        case reflection
        case complete
    }

    let recordStore: RecordStore
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.review
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
        let sourceIDs = existing?.sourceRecordIDs ?? draft.sourceRecordIDs
        _title = State(initialValue: existing?.title ?? draft.title)
        _bodyText = State(initialValue: existing?.body ?? draft.body)
        _reflection = State(initialValue: existing?.reflection ?? "")
        _emotion = State(initialValue: existing?.emotion)
        _orderedRecordIDs = State(initialValue: sourceIDs)
        _includedRecordIDs = State(initialValue: Set(sourceIDs))
    }

    var body: some View {
        Group {
            switch step {
            case .review:
                JournalReviewStep(
                    date: date,
                    title: $title,
                    bodyText: $bodyText,
                    moments: orderedMoments,
                    includedRecordIDs: $includedRecordIDs,
                    onCancel: { dismiss() },
                    onPreview: { isPreviewPresented = true },
                    onMoveUp: moveUp,
                    onMoveDown: moveDown,
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
        .navigationBarHidden(true)
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

    private func moveUp(_ id: UUID) {
        guard let index = orderedRecordIDs.firstIndex(of: id), index > 0 else { return }
        orderedRecordIDs.swapAt(index, index - 1)
    }

    private func moveDown(_ id: UUID) {
        guard let index = orderedRecordIDs.firstIndex(of: id),
              index < orderedRecordIDs.count - 1
        else { return }
        orderedRecordIDs.swapAt(index, index + 1)
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

private struct JournalReviewStep: View {
    let date: Date
    @Binding var title: String
    @Binding var bodyText: String
    let moments: [WhisperRecord]
    @Binding var includedRecordIDs: Set<UUID>
    let onCancel: () -> Void
    let onPreview: () -> Void
    let onMoveUp: (UUID) -> Void
    let onMoveDown: (UUID) -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            journalHeader(
                leading: "취소",
                title: "오늘의 일기",
                trailing: "미리보기",
                onLeading: onCancel,
                onTrailing: onPreview
            )

            ScrollView {
                VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                    VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                        Text("\(date.whisperDayDescription) · \(includedRecordIDs.count)개의 순간")
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

                    VStack(alignment: .leading, spacing: WhisperSpacing.small) {
                        Text("포함할 순간")
                            .font(.whisperSectionTitle)

                        ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                            JournalMomentSelectionRow(
                                moment: moment,
                                isIncluded: includedRecordIDs.contains(moment.id),
                                canMoveUp: index > 0,
                                canMoveDown: index < moments.count - 1,
                                onToggle: {
                                    if includedRecordIDs.contains(moment.id) {
                                        includedRecordIDs.remove(moment.id)
                                    } else {
                                        includedRecordIDs.insert(moment.id)
                                    }
                                },
                                onMoveUp: { onMoveUp(moment.id) },
                                onMoveDown: { onMoveDown(moment.id) }
                            )
                        }
                    }
                }
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.bottom, WhisperSpacing.large)
            }
            .scrollIndicators(.hidden)

            Button("다음 · 내 한 문장", action: onNext)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 25))
                .controlSize(.large)
                .disabled(
                    title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    includedRecordIDs.isEmpty
                )
                .accessibilityIdentifier("journal.nextButton")
                .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
                .padding(.bottom, WhisperSpacing.medium)
        }
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
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onToggle: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: WhisperSpacing.small) {
            Button(action: onToggle) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isIncluded ? Color.whisperAccent : Color.whisperTextSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isIncluded ? "순간 제외" : "순간 포함")

            VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                Text(moment.content)
                    .font(.whisperBody)
                    .lineLimit(1)
                Text("\(moment.createdAt.whisperTimeDescription) · \(moment.photoData == nil ? "텍스트" : "사진")")
                    .font(.whisperLabel)
                    .foregroundStyle(Color.whisperTextSecondary)
            }

            Spacer()

            Menu {
                Button("위로 이동", systemImage: "arrow.up", action: onMoveUp)
                    .disabled(!canMoveUp)
                Button("아래로 이동", systemImage: "arrow.down", action: onMoveDown)
                    .disabled(!canMoveDown)
            } label: {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Color.whisperTextSecondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("순서 바꾸기")
        }
        .padding(WhisperSpacing.small)
        .background(
            Color.whisperSurfaceDefault,
            in: RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: WhisperRadius.medium, style: .continuous)
                .stroke(Color.whisperBorderSubtle, lineWidth: 1)
        }
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
