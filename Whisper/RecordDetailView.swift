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
    let reminderCommitmentID: UUID?
    let reminderRequestIdentifier: String?

    @State private var draft: RecordDraft
    @State private var isEditing = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isPersistenceErrorPresented = false
    @State private var isReminderErrorPresented = false
    @State private var selectedEmotion: String?
    @State private var photoData: Data?
    @State private var isEmotionPickerPresented = false
    @State private var isReleaseEncounterConfirmationPresented = false
    @State private var didProcessReminderEncounter = false
    @State private var isUpdatingReminderPreference = false
    @State private var isPauseDatePickerPresented = false
    @State private var pauseUntil = Calendar.current.date(
        byAdding: .day,
        value: 30,
        to: .now
    ) ?? .now

    private let contentLimit = 1_000

    init(
        record: WhisperRecord,
        recordStore: RecordStore,
        reminderEncounterID: UUID? = nil,
        reminderCommitmentID: UUID? = nil,
        reminderRequestIdentifier: String? = nil
    ) {
        self.record = record
        self.recordStore = recordStore
        self.reminderEncounterID = reminderEncounterID
        self.reminderCommitmentID = reminderCommitmentID
        self.reminderRequestIdentifier = reminderRequestIdentifier
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
        GeometryReader { geometry in
            ScrollView {
                Group {
                    if isEditing {
                        editingContent
                            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                            .padding(.top, 12)
                            .padding(.bottom, 32)
                    } else {
                        readingContent
                            .frame(
                                minHeight: max(0, geometry.size.height - 95),
                                alignment: .top
                            )
                            .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                            .padding(.top, 33)
                            .padding(.bottom, 32)
                    }
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.whisperBackground)
        .navigationTitle(reminderEncounterID == nil ? "기록" : "다시 만난 마음")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isEditing {
                    Button("저장", action: saveChanges)
                        .disabled(!draft.canSave)
                } else {
                    Menu {
                        Button("수정", systemImage: "pencil", action: startEditing)

                        if let encounter = reminderEncounter {
                            Section("이 마음을 다시 만나는 방식") {
                                if let reaction = encounter.reaction {
                                    switch reaction {
                                    case .keep:
                                        Label("계속 기억할게요", systemImage: "sparkles")
                                        Text("잊힐 만한 순간에 다시 건넬게요.")
                                        reminderPreferenceMenuActions
                                    case .pause:
                                        Label("잠시 쉬어갈게요", systemImage: "moon.zzz.fill")
                                        Text("한동안 조용히 간직하고 있을게요.")
                                    case .release:
                                        Label("잘 놓아둘게요", systemImage: "checkmark.circle.fill")
                                        Text("다시 건네는 일은 멈추고 기록만 소중히 보관할게요.")
                                    }
                                } else {
                                    reminderPreferenceMenuActions
                                }
                            }
                        }

                        Button(
                            "삭제",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            isDeleteConfirmationPresented = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.whisperTextPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("기록 메뉴")
                }
            }
            .sharedBackgroundVisibility(.hidden)
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
            "이 마음을 이제 놓아줄까요?",
            isPresented: $isReleaseEncounterConfirmationPresented
        ) {
            Button("조금 더 기억하기", role: .cancel) {}
            Button("이제 놓아주기", role: .destructive) {
                releaseReminder()
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
        .sheet(isPresented: $isPauseDatePickerPresented) {
            pauseDatePicker
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .task(id: reminderEncounterID) {
            processReminderEncounterIfNeeded()
        }
    }

    private var readingContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let encounter = reminderEncounter, encounter.reaction == nil {
                encounterResponseCard
            }

            recordReadingCard

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

            if let commitment = displayedCommitment,
               reminderEncounter == nil || reminderEncounter?.reaction != nil {
                Spacer(minLength: 40)

                Group {
                    switch commitment.lifecycleStatus() {
                    case .active:
                        commitmentCard(commitment)
                    case .paused, .released:
                        commitmentStatusCard(commitment)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recordReadingCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.createdAt.whisperRecordHeaderDescription)
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextSecondary)

                    Text(record.title)
                        .font(.whisperScreenTitle)
                        .foregroundStyle(Color.whisperTextPrimary)
                        .padding(.trailing, 44)
                }
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)

                Rectangle()
                    .fill(Color.whisperDivider)
                    .frame(height: 1)

                Text(record.content)
                    .font(.whisperBodyLarge)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)

                if let emotion = record.emotion {
                    Text(emotion)
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperAccentText)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Color.whisperSurfaceHighlight, in: Capsule())
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                .fill(Color.whisperSurfaceDefault)
                .overlay {
                    RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
                        .stroke(Color.whisperBorderSubtle, lineWidth: 1)
                }
                .shadow(
                    color: Color(red: 94 / 255, green: 56 / 255, blue: 36 / 255)
                        .opacity(0.06),
                    radius: 18,
                    y: 6
                )
        }
        .textSelection(.enabled)
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

    private var encounterResponseCard: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            Label("다시 만난 문장", systemImage: "flame.fill")
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperAccentText)

            if let commitment = displayedCommitment {
                Text("“\(commitment.quote)”")
                    .font(.whisperBodyLarge)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("지금 이 마음을 어떻게 두고 싶나요?")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)

            Button("계속 기억하기", action: keepReminder)
                .buttonStyle(.whisperPrimary(size: .compact))
                .disabled(isUpdatingReminderPreference)

            Button {
                pauseUntil = Calendar.current.date(
                    byAdding: .day,
                    value: 30,
                    to: .now
                ) ?? .now
                isPauseDatePickerPresented = true
            } label: {
                Text("잠시 쉬기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.whisperSecondary)
            .disabled(isUpdatingReminderPreference)

            Button("이제 놓아주기") {
                isReleaseEncounterConfirmationPresented = true
            }
            .font(.whisperControl)
            .foregroundStyle(Color.whisperTextSecondary)
            .frame(maxWidth: .infinity, minHeight: WhisperSize.controlCompact)
            .disabled(isUpdatingReminderPreference)
        }
        .padding(WhisperSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .whisperCardStyle(fill: .whisperSurfaceHighlight, border: .whisperBorderSubtle)
        .accessibilityIdentifier("commitment.encounterCard")
    }

    private func commitmentCard(_: WhisperCommitment) -> some View {
        WhisperMessageCard {
            Text("이 마음은 제가 잘 간직하고 있을게요.")
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)

            Text("잊고 지낼 즈음,\n그날의 마음을 조용히 다시 건넬게요.")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private var reminderPreferenceMenuActions: some View {
        Button("잠시 쉬어갈게", systemImage: "moon.zzz.fill") {
            pauseUntil = Calendar.current.date(
                byAdding: .day,
                value: 30,
                to: .now
            ) ?? .now
            isPauseDatePickerPresented = true
        }
        .disabled(isUpdatingReminderPreference)

        Button(
            "이제 놓아줘",
            systemImage: "bell.slash",
            role: .destructive
        ) {
            isReleaseEncounterConfirmationPresented = true
        }
        .disabled(isUpdatingReminderPreference)
    }

    private var pauseDatePicker: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("언제 다시 만날까요?")
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)

                Text("정한 시각이 알림 가능 시간을 벗어나면 가까운 시간으로 맞춰드려요.")
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)

                DatePicker(
                    "다시 만날 시각",
                    selection: $pauseUntil,
                    in: Date.now.addingTimeInterval(5 * 60)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)

                Spacer()
            }
            .padding(WhisperLayout.screenHorizontalPadding)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        isPauseDatePickerPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("이때 다시 만나기") {
                        isPauseDatePickerPresented = false
                        pauseReminder(until: pauseUntil)
                    }
                }
            }
        }
    }

    private func commitmentStatusCard(_ commitment: WhisperCommitment) -> some View {
        let status = commitment.lifecycleStatus()
        let message: (title: String, description: String) = switch status {
        case .active:
            ("이 마음은 제가 간직하고 있을게요.", "잊고 지낼 즈음, 그날의 마음을 조용히 다시 건넬게요.")
        case .paused:
            ("조금 쉬어가도 괜찮아요.", "이 마음은 그대로 간직하고 있을게요.")
        case .released:
            ("이제 다시 건네지는 않을게요.", "기록은 여기 소중히 남겨둘게요.")
        }

        return WhisperMessageCard(fill: .whisperSurfaceSubtle) {
            Text(message.title)
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)

            Text(message.description)
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
        }
    }

    private var reminderEncounter: ReminderEncounter? {
        guard let reminderEncounterID,
              let encounter = recordStore.encounters.first(where: {
                  $0.id == reminderEncounterID
              }),
              let commitment = recordStore.commitments.first(where: {
                  $0.id == encounter.commitmentID
              }),
              commitment.sourceRecordID == record.id
        else {
            return nil
        }
        return encounter
    }

    private var reminderCommitment: WhisperCommitment? {
        guard let commitmentID = reminderEncounter?.commitmentID ?? reminderCommitmentID,
              let commitment = recordStore.commitments.first(where: {
                  $0.id == commitmentID
              }),
              commitment.sourceRecordID == record.id
        else {
            return nil
        }
        return commitment
    }

    private var storedCommitment: WhisperCommitment? {
        recordStore.commitments.first { $0.sourceRecordID == record.id }
    }

    private var displayedCommitment: WhisperCommitment? {
        reminderCommitment ?? storedCommitment
    }

    private func pauseReminder(until pausedUntil: Date) {
        guard let reminderEncounterID,
              let commitmentID = reminderEncounter?.commitmentID
        else {
            return
        }

        guard recordStore.react(
            to: reminderEncounterID,
            with: .pause,
            pausedUntil: pausedUntil
        ) else {
            isPersistenceErrorPresented = true
            return
        }

        scheduleReminderAfterPause(commitmentID: commitmentID)
    }

    private func keepReminder() {
        guard let reminderEncounterID else { return }
        if !recordStore.react(to: reminderEncounterID, with: .keep) {
            isPersistenceErrorPresented = true
        }
    }

    private func releaseReminder() {
        guard let reminderEncounterID,
              let commitmentID = reminderEncounter?.commitmentID
        else {
            return
        }

        guard recordStore.react(
            to: reminderEncounterID,
            with: .release
        ) else {
            isPersistenceErrorPresented = true
            return
        }

        isUpdatingReminderPreference = true
        Task {
            let didCancel = await CommitmentReminderCoordinator.cancel(
                commitmentIDs: [commitmentID],
                in: recordStore
            )
            isUpdatingReminderPreference = false
            if !didCancel {
                isReminderErrorPresented = true
            }
        }
    }

    private func scheduleReminderAfterPause(commitmentID: UUID) {
        guard let plan = recordStore.pausedReminderPlan(for: commitmentID) else {
            isPersistenceErrorPresented = true
            return
        }

        schedule(plan)
    }

    private func schedule(_ plan: CommitmentReminderPlan) {
        isUpdatingReminderPreference = true
        Task {
            let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
            isUpdatingReminderPreference = false
            if result != .scheduled {
                isReminderErrorPresented = true
            }
        }
    }

    private func processReminderEncounterIfNeeded() {
        guard !didProcessReminderEncounter,
              let reminderEncounterID
        else {
            return
        }
        didProcessReminderEncounter = true

        if reminderEncounter == nil,
           let commitmentID = reminderCommitment?.id {
            _ = recordStore.addEncounter(
                id: reminderEncounterID,
                commitmentID: commitmentID,
                scheduledAt: .now,
                notificationIdentifier: reminderRequestIdentifier
                    ?? CommitmentReminderScheduler.requestIdentifier(
                        commitmentID: commitmentID,
                        encounterID: reminderEncounterID
                    )
            )
        }

        guard reminderEncounter != nil else {
            isPersistenceErrorPresented = true
            return
        }

        if !recordStore.markEncounterOpened(reminderEncounterID) {
            isPersistenceErrorPresented = true
        }
    }

    private func startEditing() {
        resetDraft()
        isEditing = true
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

    private func emotionSystemImage(for emotion: String) -> String {
        WhisperEmotion(rawValue: emotion)?.systemImage ?? "face.smiling"
    }
}

private struct WhisperMessageCard<Content: View>: View {
    private let fill: Color
    private let content: Content

    init(
        fill: Color = .whisperSurfaceHighlight,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 35) {
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                fill,
                in: RoundedRectangle(
                    cornerRadius: 22,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        Color(red: 191 / 255, green: 212 / 255, blue: 222 / 255),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: Color(red: 94 / 255, green: 56 / 255, blue: 36 / 255)
                    .opacity(0.06),
                radius: 16,
                y: 5
            )
            .frame(maxWidth: 305)
            .frame(maxWidth: .infinity, alignment: .center)

            WhisperJar(size: .recordDetail)
                .accessibilityHidden(true)
                .frame(width: 60, height: 73)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RecordDetailPreview: View {
    private let recordStore: RecordStore
    private let record: WhisperRecord

    init() {
        let store = RecordStore(isStoredInMemoryOnly: true)
        let createdAt = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 8, day: 26, hour: 9, minute: 41)
        ) ?? .now
        let savedRecord = store.addAndReturn(
            title: "프로젝트 회고",
            content: "오늘은 팀과 오래 이야기한 끝에 방향이 선명해졌다.\n작게 시작해도 매일 이어가는 일이 중요하다는 걸 다시 느꼈다.",
            createdAt: createdAt,
            emotion: "차분함"
        )
        if let savedRecord {
            _ = store.rememberCommitment(
                sourceRecordID: savedRecord.id,
                name: "매일 이어가기",
                quote: "작게 시작해도 매일 이어가는 일이 중요하다는 걸 다시 느꼈다.",
                topics: ["꾸준함"],
                reminderTiming: .fallback
            )
        }
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
