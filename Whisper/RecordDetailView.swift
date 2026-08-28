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
    let reminderEncounterID: UUID?

    @State private var draft: RecordDraft
    @State private var isEditing = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isPersistenceErrorPresented = false
    @State private var isReminderErrorPresented = false
    @State private var selectedEmotion: String?
    @State private var photoData: Data?
    @State private var isEmotionPickerPresented = false
    @State private var isForgetCommitmentConfirmationPresented = false
    @State private var isReleaseEncounterConfirmationPresented = false
    @State private var selectedEncounterReaction: ReminderEncounterReaction?
    @State private var didProcessReminderEncounter = false
    @State private var isPreparingReminderResponse = false
    @State private var isReminderTimeEditorPresented = false
    @State private var isUpdatingReminderTime = false

    private let contentLimit = 1_000

    init(
        record: WhisperRecord,
        recordStore: RecordStore,
        reminderEncounterID: UUID? = nil
    ) {
        self.record = record
        self.recordStore = recordStore
        self.reminderEncounterID = reminderEncounterID
        _draft = State(
            initialValue: RecordDraft(
                title: record.title,
                content: record.content
            )
        )
        _selectedEmotion = State(initialValue: record.emotion)
        _photoData = State(initialValue: record.photoData)
        _selectedEncounterReaction = State(
            initialValue: reminderEncounterID.flatMap { encounterID in
                recordStore.encounters.first(where: { $0.id == encounterID })?.reaction
            }
        )
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
        .alert(
            "이 마음을 이제 놓아줄까요?",
            isPresented: $isReleaseEncounterConfirmationPresented
        ) {
            Button("조금 더 기억하기", role: .cancel) {}
            Button("이제 놓아주기", role: .destructive) {
                applyEncounterReaction(.release)
            }
        } message: {
            Text("다시 만나기 알림은 멈추지만, 기록은 보관함에 그대로 남아 있어요.")
        }
        .sheet(isPresented: $isEmotionPickerPresented) {
            EmotionPickerView(selectedEmotion: $selectedEmotion)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(.clear)
        }
        .sheet(isPresented: $isReminderTimeEditorPresented) {
            if let commitment = storedCommitment,
               commitment.lifecycleStatus() == .active {
                ReminderTimeEditorSheet(
                    currentDate: commitment.nextReminderAt,
                    onSave: { date in
                        updateReminderDate(commitmentID: commitment.id, date: date)
                    },
                    onUseAI: {
                        requestAIReminderDate(commitmentID: commitment.id)
                    }
                )
                .presentationDetents([.fraction(0.46), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
        }
        .task(id: reminderEncounterID) {
            await processReminderEncounterIfNeeded()
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

            if let encounter = reminderEncounter,
               let commitment = reminderCommitment {
                reminderResponseCard(encounter: encounter, commitment: commitment)
            } else if let commitment = storedCommitment {
                switch commitment.lifecycleStatus() {
                case .active:
                    commitmentCard(commitment)
                case .paused, .released:
                    commitmentStatusCard(commitment)
                }
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

            fieldLabel(RecordWritingCopy.titleLabel)
            TextField(RecordWritingCopy.titleExample, text: $draft.title)
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

            Text(RecordWritingCopy.titleHelp)
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)

            fieldLabel(RecordWritingCopy.contentLabel)
            ZStack(alignment: .bottomTrailing) {
                TextField(
                    RecordWritingCopy.contentExample,
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

            nextReminderRow(commitment)

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

    private func reminderResponseCard(
        encounter: ReminderEncounter,
        commitment: WhisperCommitment
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("다시 만난 마음", systemImage: "sparkles")
                .font(.whisperControl)
                .foregroundStyle(Color.whisperAccentText)

            Text("“\(commitment.quote)”")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextPrimary)
                .lineSpacing(4)

            if let reaction = selectedEncounterReaction ?? encounter.reaction {
                encounterReactionConfirmation(reaction)
            } else {
                Text("읽은 것만으로도 충분해요. 원한다면 이 마음을 앞으로 어떻게 만날지 알려주세요.")
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .lineSpacing(3)

                if isPreparingReminderResponse {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("다음 만남을 정리하고 있어요…")
                            .font(.whisperCaption)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }
                }

                Button("계속 기억해줘") {
                    applyEncounterReaction(.keep)
                }
                .buttonStyle(.whisperPrimary(size: .compact))
                .disabled(isPreparingReminderResponse)

                Button("30일 동안 쉬어갈게") {
                    applyEncounterReaction(.pause)
                }
                .buttonStyle(.whisperSecondary)
                .disabled(isPreparingReminderResponse)

                Button("이제 놓아줘") {
                    isReleaseEncounterConfirmationPresented = true
                }
                .font(.whisperControl)
                .foregroundStyle(Color.whisperTextSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(isPreparingReminderResponse)
            }

            if commitment.lifecycleStatus() == .active,
               !isPreparingReminderResponse {
                nextReminderRow(commitment)
            }
        }
        .padding(16)
        .whisperCardStyle(
            fill: .whisperSurfaceHighlight,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.large
        )
    }

    private func commitmentStatusCard(_ commitment: WhisperCommitment) -> some View {
        let status = commitment.lifecycleStatus()
        let message: (icon: String, title: String, description: String) = switch status {
        case .active:
            ("sparkles", "Whisper가 기억 중인 불꽃", "잊힐 만한 순간에 다시 건넬게요.")
        case .paused:
            (
                "moon.zzz.fill",
                "잠시 쉬어가는 불꽃",
                commitment.pausedUntil.map {
                    "\($0.whisperDateDescription)에 다시 만나요."
                } ?? "잠시 뒤 다시 만나요."
            )
        case .released:
            ("checkmark.circle.fill", "잘 놓아준 마음", "알림은 멈췄지만 기록은 그대로 남아 있어요.")
        }

        return Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.whisperBodyEmphasis)
                    .foregroundStyle(Color.whisperTextPrimary)
                Text(message.description)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
        } icon: {
            Image(systemName: message.icon)
                .foregroundStyle(Color.whisperAccent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .whisperCardStyle(
            fill: .whisperSurfaceSubtle,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.large
        )
    }

    private func nextReminderRow(_ commitment: WhisperCommitment) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(Color.whisperAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("다음 만남")
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)

                if isUpdatingReminderTime {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("AI가 시간을 정하고 있어요…")
                            .font(.whisperMetadata)
                            .foregroundStyle(Color.whisperTextPrimary)
                    }
                } else if let nextReminderAt = commitment.nextReminderAt {
                    Text(nextReminderAt.whisperDateTimeDescription)
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextPrimary)
                } else {
                    Text("다음 시간을 정하는 중이에요")
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextPrimary)
                }
            }

            Spacer(minLength: 4)

            Button("바꾸기") {
                isReminderTimeEditorPresented = true
            }
            .font(.whisperCaption)
            .disabled(isUpdatingReminderTime)
        }
        .padding(12)
        .accessibilityIdentifier("detail.nextReminder")
        .background(
            Color.whisperSurfaceDefault,
            in: RoundedRectangle(
                cornerRadius: WhisperRadius.medium,
                style: .continuous
            )
        )
    }

    private func encounterReactionConfirmation(
        _ reaction: ReminderEncounterReaction
    ) -> some View {
        let message: (icon: String, title: String, description: String) = switch reaction {
        case .keep:
            ("sparkles", "계속 기억할게요", "잊힐 만한 순간에 다시 건넬게요.")
        case .pause:
            ("moon.zzz.fill", "잠시 쉬어갈게요", "30일 뒤에 다시 만나요.")
        case .release:
            ("checkmark.circle.fill", "잘 놓아둘게요", "알림은 멈추고 기록만 소중히 보관할게요.")
        }

        return Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(message.title)
                    .font(.whisperBodyEmphasis)
                    .foregroundStyle(Color.whisperTextPrimary)
                Text(message.description)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
        } icon: {
            Image(systemName: message.icon)
                .foregroundStyle(Color.whisperAccent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.whisperSurfaceDefault,
            in: RoundedRectangle(
                cornerRadius: WhisperRadius.medium,
                style: .continuous
            )
        )
    }

    private var reminderEncounter: ReminderEncounter? {
        guard let reminderEncounterID else { return nil }
        return recordStore.encounters.first { $0.id == reminderEncounterID }
    }

    private var reminderCommitment: WhisperCommitment? {
        guard let commitmentID = reminderEncounter?.commitmentID else { return nil }
        return recordStore.commitments.first { $0.id == commitmentID }
    }

    private var storedCommitment: WhisperCommitment? {
        recordStore.commitments.first { $0.sourceRecordID == record.id }
    }

    private func applyEncounterReaction(_ reaction: ReminderEncounterReaction) {
        guard let reminderEncounterID,
              let commitmentID = reminderEncounter?.commitmentID
        else {
            return
        }
        if recordStore.react(to: reminderEncounterID, with: reaction) {
            selectedEncounterReaction = reaction
            if reaction == .pause {
                scheduleReminderAfterPause(commitmentID: commitmentID)
            }
        } else {
            isPersistenceErrorPresented = true
        }
    }

    private func scheduleReminderAfterPause(commitmentID: UUID) {
        guard let plan = recordStore.pausedReminderPlan(for: commitmentID) else {
            isPersistenceErrorPresented = true
            return
        }

        Task {
            let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
            if result != .scheduled {
                isReminderErrorPresented = true
            }
        }
    }

    private func updateReminderDate(commitmentID: UUID, date: Date) {
        let adjustedDate = CommitmentReminderScheduler.adjustedToAllowedReminderHours(date)
        guard let plan = recordStore.rescheduleCommitment(
            commitmentID,
            firstReminderDate: adjustedDate
        ) else {
            isPersistenceErrorPresented = true
            return
        }

        isUpdatingReminderTime = true
        Task {
            let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
            isUpdatingReminderTime = false
            if result != .scheduled {
                isReminderErrorPresented = true
            }
        }
    }

    private func requestAIReminderDate(commitmentID: UUID) {
        guard let context = recordStore.reminderPlanningContext(for: commitmentID) else {
            isPersistenceErrorPresented = true
            return
        }

        isUpdatingReminderTime = true
        Task {
            let timing = await CommitmentAnalyzer().replanReminder(
                for: context,
                eventDescription: "사용자가 다음 만남 시각을 AI에게 다시 맡겼습니다."
            )
            guard let plan = recordStore.rescheduleCommitment(
                commitmentID,
                reminderTiming: timing
            ) else {
                isUpdatingReminderTime = false
                isPersistenceErrorPresented = true
                return
            }

            let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
            isUpdatingReminderTime = false
            if result != .scheduled {
                isReminderErrorPresented = true
            }
        }
    }

    private func processReminderEncounterIfNeeded() async {
        guard !didProcessReminderEncounter,
              let reminderEncounterID,
              let encounter = recordStore.encounters.first(where: { $0.id == reminderEncounterID })
        else {
            return
        }
        didProcessReminderEncounter = true
        isPreparingReminderResponse = true
        defer { isPreparingReminderResponse = false }

        guard recordStore.markEncounterOpened(reminderEncounterID),
              let context = recordStore.reminderPlanningContext(for: encounter.commitmentID)
        else {
            return
        }

        let timing = await CommitmentAnalyzer().replanReminder(
            for: context,
            eventDescription: "사용자가 리마인드된 마음을 다시 읽었습니다."
        )
        guard let plan = recordStore.rescheduleCommitment(
            encounter.commitmentID,
            reminderTiming: timing
        ) else {
            return
        }

        let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
        if result != .scheduled,
           let commitment = recordStore.commitments.first(where: { $0.id == encounter.commitmentID }),
           commitment.lifecycleStatus() == .active {
            isReminderErrorPresented = true
        }
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
