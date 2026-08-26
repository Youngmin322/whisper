//
//  RecordDetailView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let record: WhisperRecord
    let recordStore: RecordStore

    @State private var draft: RecordDraft
    @State private var isEditing = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isPersistenceErrorPresented = false
    @State private var isReminderErrorPresented = false
    @State private var selectedEmotion: String?
    @State private var photoData: Data?
    @State private var isEmotionPickerPresented = false
    @State private var isForgetCommitmentConfirmationPresented = false

    private let contentLimit = 1_000

    init(record: WhisperRecord, recordStore: RecordStore) {
        self.record = record
        self.recordStore = recordStore
        _draft = State(
            initialValue: RecordDraft(
                title: record.title,
                content: record.content
            )
        )
        _selectedEmotion = State(initialValue: record.emotion)
        _photoData = State(initialValue: record.photoData)
    }

    var body: some View {
        ScrollView {
            Group {
                if isEditing {
                    editingContent
                } else {
                    readingContent
                }
            }
            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color.whisperBackground)
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if isEditing {
                    Button("취소", action: cancelEditing)
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                if isEditing {
                    Button("저장", action: saveChanges)
                        .disabled(!draft.canSave)
                } else {
                    Menu {
                        Button("수정", systemImage: "pencil", action: startEditing)
                        Button(
                            "삭제",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            isDeleteConfirmationPresented = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("기록 메뉴")
                }
            }
        }
        .alert("이 기록을 삭제할까요?", isPresented: $isDeleteConfirmationPresented) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive, action: deleteRecord)
        } message: {
            Text("삭제한 기록은 다시 복구할 수 없어요.")
        }
        .alert("변경사항을 저장할 수 없어요", isPresented: $isPersistenceErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("잠시 후 다시 시도해 주세요.")
        }
        .alert("다시 만나기 알림을 설정할 수 없어요", isPresented: $isReminderErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("알림 권한과 설정을 확인한 뒤 다시 시도해 주세요.")
        }
        .alert(
            "이 불꽃을 그만 기억할까요?",
            isPresented: $isForgetCommitmentConfirmationPresented
        ) {
            Button("취소", role: .cancel) {}
            Button("그만 기억하기", role: .destructive, action: forgetCommitment)
        } message: {
            Text("예약된 다시 만나기 알림도 함께 사라져요. 기록은 그대로 남아 있어요.")
        }
        .sheet(isPresented: $isEmotionPickerPresented) {
            EmotionPickerView(selectedEmotion: $selectedEmotion)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.clear)
        }
    }

    private var readingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(record.createdAt.whisperFullDayDescription)
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)

            Text(record.title)
                .font(.whisperScreenTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            if let emotion = record.emotion {
                Label(emotion, systemImage: emotionSystemImage(for: emotion))
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperAccentText)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(
                        Color.whisperSurfaceHighlight,
                        in: Capsule()
                    )
            }

            Text(record.content)
                .font(.whisperBodyLarge)
                .foregroundStyle(Color.whisperTextPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .whisperCardStyle(
                    fill: .whisperSurfaceDefault,
                    border: .whisperBorderSubtle,
                    cornerRadius: WhisperRadius.large
                )
                .textSelection(.enabled)

            if let commitment = recordStore.commitment(sourceRecordID: record.id) {
                commitmentCard(commitment)
            }

            if let photoData = record.photoData {
                RecordPhotoView(photoData: photoData)
            }

            if let focusMode = record.focusMode {
                Label(focusMode, systemImage: "moon.stars.fill")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperAccentText)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        Color.whisperSurfaceFocus,
                        in: RoundedRectangle(
                            cornerRadius: WhisperRadius.medium,
                            style: .continuous
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(record.createdAt.whisperFullDayDescription)
                .font(.whisperMetadata)
                .foregroundStyle(Color.whisperTextSecondary)

            fieldLabel("제목")
            TextField("오늘의 마음에 제목을 붙여주세요", text: $draft.title)
                .font(.whisperBodyLarge)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    Color.whisperSurfaceSubtle,
                    in: RoundedRectangle(
                        cornerRadius: WhisperRadius.medium,
                        style: .continuous
                    )
                )

            fieldLabel("기록")
            ZStack(alignment: .bottomTrailing) {
                TextField(
                    "오늘 있었던 일과 생각을 천천히 적어보세요",
                    text: $draft.content,
                    axis: .vertical
                )
                .font(.whisperBodyLarge)
                .lineSpacing(5)
                .lineLimit(8 ... 14)
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                .onChange(of: draft.content) { _, newValue in
                    guard newValue.count > contentLimit else { return }
                    draft.content = String(newValue.prefix(contentLimit))
                }

                Text("\(draft.content.count) / \(contentLimit.formatted())")
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .padding(16)
            }
            .background(
                Color.whisperSurfaceSubtle,
                in: RoundedRectangle(
                    cornerRadius: WhisperRadius.medium,
                    style: .continuous
                )
            )

            fieldLabel("감정")
            Button {
                isEmotionPickerPresented = true
            } label: {
                HStack {
                    Label(
                        selectedEmotion ?? "선택 안 함",
                        systemImage: selectedEmotion.map(emotionSystemImage) ?? "circle.dashed"
                    )
                    .font(.whisperBodyEmphasis)
                    .foregroundStyle(Color.whisperTextPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.whisperTextSecondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    Color.whisperSurfaceSubtle,
                    in: RoundedRectangle(
                        cornerRadius: WhisperRadius.medium,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)

            fieldLabel("사진")
            PhotoAttachmentEditor(photoData: $photoData)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.whisperFieldLabel)
            .foregroundStyle(Color.whisperTextPrimary)
    }

    private func commitmentCard(_ commitment: WhisperCommitment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Whisper가 기억 중인 불꽃", systemImage: "sparkles")
                .font(.whisperControl)
                .foregroundStyle(Color.whisperAccentText)

            Text("“\(commitment.quote)”")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextPrimary)
                .lineSpacing(4)

            Text("반응이 없으면 조금씩 더 긴 간격으로 다시 건넬게요.")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)

            HStack(spacing: 10) {
                Button("계속 기억해줘") {
                    continueCommitment(commitment)
                }
                .buttonStyle(.whisperSecondary)

                Button("이제 괜찮아요") {
                    isForgetCommitmentConfirmationPresented = true
                }
                .font(.whisperControl)
                .foregroundStyle(Color.whisperTextSecondary)
            }
        }
        .padding(16)
        .whisperCardStyle(
            fill: .whisperSurfaceHighlight,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.large
        )
    }

    private func startEditing() {
        resetDraft()
        isEditing = true
    }

    private func cancelEditing() {
        resetDraft()
        isEditing = false
    }

    private func resetDraft() {
        draft = RecordDraft(title: record.title, content: record.content)
        selectedEmotion = record.emotion
        photoData = record.photoData
    }

    private func saveChanges() {
        let didSave = recordStore.update(
            record,
            title: draft.titleForSaving,
            content: draft.contentForSaving,
            emotion: selectedEmotion,
            photoData: photoData
        )

        if didSave {
            resetDraft()
            isEditing = false
        } else {
            isPersistenceErrorPresented = true
        }
    }

    private func deleteRecord() {
        if recordStore.delete(record) {
            dismiss()
        } else {
            isPersistenceErrorPresented = true
        }
    }

    private func continueCommitment(_ commitment: WhisperCommitment) {
        guard let context = recordStore.reminderPlanningContext(for: commitment.id) else { return }

        Task {
            let timing = await CommitmentAnalyzer().replanReminder(
                for: context,
                eventDescription: "사용자가 이 결심을 이어가겠다고 표시했습니다."
            )
            guard let plan = recordStore.continueCommitment(
                commitment.id,
                reminderTiming: timing
            ) else {
                return
            }
            let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
            if result != .scheduled {
                isReminderErrorPresented = true
            }
        }
    }

    private func forgetCommitment() {
        guard let commitment = recordStore.commitment(sourceRecordID: record.id) else { return }
        _ = recordStore.forgetCommitment(commitment)
    }

    private func emotionSystemImage(for emotion: String) -> String {
        WhisperEmotion(rawValue: emotion)?.systemImage ?? "face.smiling"
    }
}

private struct RecordDetailPreview: View {
    private let recordStore: RecordStore
    private let record: WhisperRecord

    init() {
        let store = RecordStore(isStoredInMemoryOnly: true)
        store.add(
            title: "오늘의 작은 결심",
            content: "조급해하지 말고 지금 할 수 있는 한 가지에 집중해 보기로 했다."
        )
        recordStore = store
        record = store.records[0]
    }

    var body: some View {
        NavigationStack {
            RecordDetailView(record: record, recordStore: recordStore)
        }
    }
}

#Preview { RecordDetailPreview() }
