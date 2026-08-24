//
//  RecordDetailView.swift
//  Ember
//

import SwiftUI
import EmberDesignSystem

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let record: EmberRecord
    let recordStore: RecordStore

    @State private var draft: RecordDraft
    @State private var isEditing = false
    @State private var isDeleteConfirmationPresented = false
    @State private var isPersistenceErrorPresented = false
    @State private var selectedEmotion: String?
    @State private var photoData: Data?
    @State private var isEmotionPickerPresented = false

    private let contentLimit = 1_000

    init(record: EmberRecord, recordStore: RecordStore) {
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
            .padding(.horizontal, EmberLayout.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color.emberBackground)
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
        .sheet(isPresented: $isEmotionPickerPresented) {
            EmotionPickerView(selectedEmotion: $selectedEmotion)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    private var readingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(record.createdAt.emberFullDayDescription)
                .font(.emberMetadata)
                .foregroundStyle(Color.emberTextSecondary)

            Text(record.title)
                .font(.emberScreenTitle)
                .foregroundStyle(Color.emberTextPrimary)

            if let emotion = record.emotion {
                Label(emotion, systemImage: emotionSystemImage(for: emotion))
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberAccentText)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(
                        Color.emberSurfaceHighlight,
                        in: Capsule()
                    )
            }

            Text(record.content)
                .font(.emberBodyLarge)
                .foregroundStyle(Color.emberTextPrimary)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .emberCardStyle(
                    fill: .emberSurfaceDefault,
                    border: .emberBorderSubtle,
                    cornerRadius: EmberRadius.large
                )
                .textSelection(.enabled)

            if let photoData = record.photoData {
                RecordPhotoView(photoData: photoData)
            }

            if let focusMode = record.focusMode {
                Label(focusMode, systemImage: "moon.stars.fill")
                    .font(.emberMetadata)
                    .foregroundStyle(Color.emberAccentText)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        Color.emberSurfaceFocus,
                        in: RoundedRectangle(
                            cornerRadius: EmberRadius.medium,
                            style: .continuous
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(record.createdAt.emberFullDayDescription)
                .font(.emberMetadata)
                .foregroundStyle(Color.emberTextSecondary)

            fieldLabel("제목")
            TextField("오늘의 마음에 제목을 붙여주세요", text: $draft.title)
                .font(.emberBodyLarge)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    Color.emberSurfaceSubtle,
                    in: RoundedRectangle(
                        cornerRadius: EmberRadius.medium,
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
                .font(.emberBodyLarge)
                .lineSpacing(5)
                .lineLimit(8 ... 14)
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                .onChange(of: draft.content) { _, newValue in
                    guard newValue.count > contentLimit else { return }
                    draft.content = String(newValue.prefix(contentLimit))
                }

                Text("\(draft.content.count) / \(contentLimit.formatted())")
                    .font(.emberCaption)
                    .foregroundStyle(Color.emberTextSecondary)
                    .padding(16)
            }
            .background(
                Color.emberSurfaceSubtle,
                in: RoundedRectangle(
                    cornerRadius: EmberRadius.medium,
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
                    .font(.emberBodyEmphasis)
                    .foregroundStyle(Color.emberTextPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.emberTextSecondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    Color.emberSurfaceSubtle,
                    in: RoundedRectangle(
                        cornerRadius: EmberRadius.medium,
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
            .font(.emberFieldLabel)
            .foregroundStyle(Color.emberTextPrimary)
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

    private func emotionSystemImage(for emotion: String) -> String {
        EmberEmotion(rawValue: emotion)?.systemImage ?? "face.smiling"
    }
}

private struct RecordDetailPreview: View {
    private let recordStore: RecordStore
    private let record: EmberRecord

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
