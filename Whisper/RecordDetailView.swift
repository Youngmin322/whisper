//
//  RecordDetailView.swift
//  Whisper
//

import SwiftUI
import PhotosUI
import WhisperDesignSystem

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var isDraftErrorPresented = false
    @State private var isDiscardDraftConfirmationPresented = false
    @State private var originalDraft: RecordDraft
    @State private var photoLoader: PhotoAttachmentLoader
    @State private var isEmotionPickerPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhoto: DiaryPhoto?
    @State private var isBodyFocused = false
    @State private var photoInsertionOffset = 0
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
        reminderRequestIdentifier: String? = nil,
        editingDraft: RecordDraft? = nil
    ) {
        self.record = record
        self.recordStore = recordStore
        self.reminderEncounterID = reminderEncounterID
        self.reminderCommitmentID = reminderCommitmentID
        self.reminderRequestIdentifier = reminderRequestIdentifier
        let original = RecordDraft(title: record.title, content: record.content, emotion: record.emotion,
            photoData: record.photoData, document: recordStore.diaryDocument(for: record).withoutPhotoData,
            existingRecordID: record.id)
        let value = editingDraft ?? recordStore.writingDraftStore.momentEditDraft(for: record.id) ?? original
        _draft = State(initialValue: value)
        _originalDraft = State(initialValue: original)
        _isEditing = State(initialValue: editingDraft != nil)
        _photoInsertionOffset = State(initialValue: value.content.utf16.count)
        _photoLoader = State(initialValue: PhotoAttachmentLoader(photoData: value.photoData))
    }

    private var detailContent: some View {
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
        .navigationTitle(reminderEncounterID == nil ? "남긴 순간" : "다시 만난 마음")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if isEditing { Button("닫기", action: closeEditing).accessibilityHint("수정 중인 초안을 보관해요.") }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("초안 버리기", systemImage: "trash", role: .destructive) {
                        isDiscardDraftConfirmationPresented = true
                    }
                    .accessibilityIdentifier("record.discardEditDraftButton")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isEditing {
                    Button("저장", action: saveChanges)
                        .disabled(!draft.canSave || photoLoader.isLoading)
                        .accessibilityIdentifier("record.saveEditButton")
                } else {
                    Menu {
                        Button("수정", systemImage: "pencil", action: startEditing)

                        if CommitmentReminderFeature.isEnabled,
                           let commitment = displayedCommitment {
                            Section("결심 알림") {
                                switch commitment.lifecycleStatus() {
                                case .active:
                                    reminderPreferenceMenuActions
                                case .paused:
                                    Label("쉬는 중", systemImage: "moon.zzz.fill")
                                    Button("이제 놓아줘", systemImage: "bell.slash", role: .destructive) {
                                        isReleaseEncounterConfirmationPresented = true
                                    }
                                case .released:
                                    Label("중단됨", systemImage: "bell.slash")
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
    }

    private var detailWithAlerts: some View {
        detailContent
        .alert("이 기록을 삭제할까요?", isPresented: $isDeleteConfirmationPresented) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive, action: deleteRecord)
        } message: {
            Text(deleteConfirmationMessage)
        }
        .alert("변경사항을 저장할 수 없어요", isPresented: $isPersistenceErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("잠시 후 다시 시도해 주세요.")
        }
        .alert("초안을 보관할 수 없어요", isPresented: $isDraftErrorPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("수정한 내용은 이 화면에 남아 있어요. 임시 저장을 다시 시도해 주세요.")
        }
        .confirmationDialog("수정 중인 초안을 버릴까요?", isPresented: $isDiscardDraftConfirmationPresented, titleVisibility: .visible) {
            Button("초안 버리기", role: .destructive) {
                guard recordStore.writingDraftStore.discard(id: draft.id) else {
                    isDraftErrorPresented = true
                    return
                }
                isEditing = false
                isBodyFocused = false
                resetDraft()
            }
            Button("계속 작성", role: .cancel) {}
        } message: { Text("이미 저장한 순간은 그대로 남아요.") }
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
    }

    var body: some View {
        detailWithAlerts
        .sheet(isPresented: $isEmotionPickerPresented) {
            EmotionPickerView(selectedEmotion: $draft.emotion)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPauseDatePickerPresented) {
            pauseDatePicker
                .presentationDetents([.large])
        }
        .sheet(item: $selectedPhoto) { DiaryPhotoViewer(photo: $0) }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: Binding(
            get: { photoLoader.selectedItem }, set: { photoLoader.select($0) }
        ), matching: .images)
        .onChange(of: photoLoader.photoData) { _, data in
            if isEditing { draft.attachPhoto(data, at: photoInsertionOffset) }
        }
        .alert("사진을 불러올 수 없어요", isPresented: Binding<Bool>(
            get: { photoLoader.errorMessage != nil },
            set: { if !$0 { photoLoader.dismissError() } }
        )) {
            Button("확인", role: .cancel) { photoLoader.dismissError() }
        } message: { Text(photoLoader.errorMessage ?? "다른 사진으로 다시 시도해 주세요.") }
        .onAppear { persistDraft() }
        .onChange(of: draft) { _, _ in persistDraft() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { persistDraft() } }
        .onDisappear { persistDraft(); photoLoader.cancelLoading() }
        .task(id: reminderEncounterID) {
            processReminderEncounterIfNeeded()
        }
    }

    private var readingContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if recordStore.writingDraftStore.momentEditDraft(for: record.id) != nil {
                Button("보관한 수정 초안 이어 쓰기", action: startEditing)
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperAccentText)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("record.resumeEditDraftButton")
            }
            if let encounter = reminderEncounter,
               encounter.reaction == nil,
               displayedCommitment?.lifecycleStatus() == .active {
                encounterResponseCard
            }

            recordReadingCard

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

            if CommitmentReminderFeature.isEnabled,
               let commitment = displayedCommitment,
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
        VStack(alignment: .leading, spacing: 22) {
            DiaryPageHeader(date: record.createdAt.whisperRecordHeaderDescription,
                            title: record.title, emotion: record.emotion)
            DiaryTextView(document: .constant(recordStore.diaryDocument(for: record)),
                          isFocused: .constant(false), isEditable: false, minimumHeight: 0,
                          onPhotoTap: { selectedPhoto = $0 })
        }
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            WritingDraftErrorView(message: recordStore.writingDraftStore.errorMessage) { persistDraft() }
            HStack {
                Text(record.createdAt.whisperFullDayDescription)
                    .font(.whisperMetadata).foregroundStyle(Color.whisperTextSecondary)
                Spacer()
                Button { isBodyFocused = false; isEmotionPickerPresented = true } label: {
                    FlameCharacter(emotion: draft.emotion, size: 38).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("감정 바꾸기, 현재 \(draft.emotion ?? "선택 안 함")")
            }
            TextField("이 순간의 제목 · 선택 사항", text: $draft.title, axis: .vertical)
                .font(.whisperHandwriting(28, bold: true))
                .foregroundStyle(Color.whisperTextPrimary)
                .accessibilityIdentifier("record.editTitleField")
            Rectangle().fill(Color.whisperDivider).frame(height: 1)
            DiaryTextView(document: Binding(
                get: { draft.diaryDocument },
                set: { value in
                    draft.setDiaryDocument(value)
                    if photoLoader.photoData != draft.photoData { photoLoader.replacePhoto(with: draft.photoData) }
                }
            ), isFocused: $isBodyFocused, minimumHeight: 260,
               accessibilityIdentifier: "record.editContentField",
               onSelectionChange: { photoInsertionOffset = $0 },
               onPhotoTap: { selectedPhoto = $0 })
            if draft.content.count >= contentLimit - 100 {
                Text("\(draft.content.count) / \(contentLimit.formatted())")
                    .font(.whisperCaption)
                    .foregroundStyle(draft.content.count > contentLimit ? .red : Color.whisperTextSecondary)
            }
            HStack {
                Button { isBodyFocused = false; isPhotoPickerPresented = true } label: {
                    if photoLoader.isLoading { ProgressView() }
                    else { Label(draft.photoData == nil ? "사진 붙이기" : "사진 바꾸기", systemImage: "photo") }
                }
                .disabled(photoLoader.isLoading)
                if draft.photoData != nil {
                    Button("사진 삭제", role: .destructive) { photoLoader.replacePhoto(with: nil) }
                }
                Spacer(minLength: 0)
                if isBodyFocused {
                    Button { isBodyFocused = false } label: { Image(systemName: "keyboard.chevron.compact.down") }
                        .accessibilityLabel("키보드 내리기")
                }
            }
            .font(.whisperControl).buttonStyle(.plain)
            .foregroundStyle(Color.whisperTextSecondary)
        }
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
        WhisperMessageCard(emotion: record.emotion) {
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
            Form {
                Section {
                    DatePicker(
                        "다시 만날 시각",
                        selection: $pauseUntil,
                        in: Date.now.addingTimeInterval(5 * 60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                } footer: {
                    Text("정한 시각이 알림 가능 시간을 벗어나면 가까운 시간으로 맞춰드려요.")
                }
            }
            .navigationTitle("알림 쉬기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        isPauseDatePickerPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("이때까지 쉬기") {
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

        return WhisperMessageCard(fill: .whisperSurfaceSubtle, emotion: record.emotion) {
            Text(message.title)
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)

            Text(message.description)
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
        }
    }

    private var reminderEncounter: ReminderEncounter? {
        guard CommitmentReminderFeature.isEnabled,
              let reminderEncounterID,
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
        guard CommitmentReminderFeature.isEnabled else { return nil }
        return reminderCommitment ?? storedCommitment
    }

    private var deleteConfirmationMessage: String {
        if CommitmentReminderFeature.isEnabled {
            return "이 순간의 원문과 사진, 연결된 결심 알림이 삭제돼요. 일기에 복사한 문장은 그대로 남고 출처는 삭제된 순간으로 표시돼요. 삭제한 원본은 복구할 수 없어요."
        }
        return "이 순간의 원문과 사진이 삭제돼요. 일기에 복사한 문장은 그대로 남고 출처는 삭제된 순간으로 표시돼요. 삭제한 원본은 복구할 수 없어요."
    }

    private func pauseReminder(until pausedUntil: Date) {
        guard let commitment = displayedCommitment,
              commitment.lifecycleStatus() == .active else { return }
        let commitmentID = commitment.id
        let didSave: Bool
        if let encounter = reminderEncounter, encounter.reaction == nil {
            didSave = recordStore.react(to: encounter.id, with: .pause, pausedUntil: pausedUntil)
        } else {
            didSave = recordStore.pauseCommitment(commitmentID, until: pausedUntil)
        }
        guard didSave else {
            isPersistenceErrorPresented = true
            return
        }
        scheduleReminderAfterPause(commitmentID: commitmentID)
    }

    private func keepReminder() {
        guard let reminderEncounterID,
              displayedCommitment?.lifecycleStatus() == .active else { return }
        if !recordStore.react(to: reminderEncounterID, with: .keep) {
            isPersistenceErrorPresented = true
        }
    }

    private func releaseReminder() {
        guard let commitment = displayedCommitment,
              commitment.lifecycleStatus() != .released else { return }
        let commitmentID = commitment.id
        let didSave: Bool
        if let encounter = reminderEncounter, encounter.reaction == nil,
           commitment.lifecycleStatus() == .active {
            didSave = recordStore.react(to: encounter.id, with: .release)
        } else {
            didSave = recordStore.forgetCommitment(commitment)
        }
        guard didSave else {
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
        isUpdatingReminderPreference = true
        Task {
            let didCancel = await CommitmentReminderCoordinator.cancel(
                commitmentIDs: [commitmentID],
                in: recordStore
            )
            guard didCancel else {
                isUpdatingReminderPreference = false
                isReminderErrorPresented = true
                return
            }
            let result = await CommitmentReminderCoordinator.schedule(plan, in: recordStore)
            isUpdatingReminderPreference = false
            if result != .scheduled {
                isReminderErrorPresented = true
            }
        }
    }

    private func processReminderEncounterIfNeeded() {
        guard CommitmentReminderFeature.isEnabled,
              !didProcessReminderEncounter,
              let reminderEncounterID
        else {
            return
        }
        didProcessReminderEncounter = true

        if reminderEncounter == nil,
           let commitment = reminderCommitment,
           commitment.lifecycleStatus() == .active {
            guard recordStore.addEncounter(
                id: reminderEncounterID,
                commitmentID: commitment.id,
                scheduledAt: .now,
                notificationIdentifier: reminderRequestIdentifier
                    ?? CommitmentReminderScheduler.requestIdentifier(
                        commitmentID: commitment.id,
                        encounterID: reminderEncounterID
                    )
            ) != nil else {
                isPersistenceErrorPresented = true
                return
            }
        }

        guard reminderEncounter != nil else { return }

        if !recordStore.markEncounterOpened(reminderEncounterID) {
            isPersistenceErrorPresented = true
        }
    }

    private func startEditing() {
        resetDraft()
        if let restored = recordStore.writingDraftStore.momentEditDraft(for: record.id) {
            draft = restored
            photoLoader.replacePhoto(with: restored.photoData)
            photoInsertionOffset = restored.content.utf16.count
        }
        isEditing = true
        isBodyFocused = true
    }

    private func resetDraft() {
        draft = RecordDraft(title: record.title, content: record.content, emotion: record.emotion, photoData: record.photoData,
                            document: recordStore.diaryDocument(for: record).withoutPhotoData, existingRecordID: record.id)
        originalDraft = draft
        photoInsertionOffset = record.content.utf16.count
        photoLoader.replacePhoto(with: record.photoData)
    }

    private func saveChanges() {
        guard draft.canSave, !photoLoader.isLoading else { return }
        let didSave = recordStore.saveMomentEditDraft(draft) != nil

        if didSave {
            isEditing = false
            isBodyFocused = false
            resetDraft()
        } else {
            isPersistenceErrorPresented = true
        }
    }

    @discardableResult
    private func persistDraft() -> Bool {
        guard isEditing else { return true }
        // Entering edit mode alone should not create a draft. Photo positions count as edits.
        let samePhotos = draft.diaryDocument.photos.map(\.offset) == originalDraft.diaryDocument.photos.map(\.offset)
        let unchanged = draft.title == originalDraft.title && draft.content == originalDraft.content
            && draft.emotion == originalDraft.emotion && draft.photoData == originalDraft.photoData && samePhotos
        if unchanged {
            guard recordStore.writingDraftStore.momentEditDraft(for: record.id) != nil else { return true }
            return recordStore.writingDraftStore.discard(id: draft.id)
        }
        return recordStore.writingDraftStore.save(draft)
    }

    private func closeEditing() {
        guard persistDraft() else { isDraftErrorPresented = true; return }
        isBodyFocused = false
        isEditing = false
        photoLoader.cancelLoading()
    }

    private func deleteRecord() {
        if recordStore.delete(record) {
            dismiss()
        } else {
            isPersistenceErrorPresented = true
        }
    }

}

private struct WhisperMessageCard<Content: View>: View {
    private let fill: Color
    private let emotion: String?
    private let content: Content

    init(
        fill: Color = .whisperSurfaceHighlight,
        emotion: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.emotion = emotion
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

            WhisperJar(size: .recordDetail, emotion: emotion)
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
