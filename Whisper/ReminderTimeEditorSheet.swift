//
//  ReminderTimeEditorSheet.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct ReminderTimeEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    private let minimumReminderDate: Date
    private let maximumReminderDate: Date
    let onSave: (Date) -> Void
    let onUseAI: () -> Void

    init(
        currentDate: Date?,
        onSave: @escaping (Date) -> Void,
        onUseAI: @escaping () -> Void
    ) {
        let now = Date.now
        let minimumDate = now.addingTimeInterval(60 * 60)
        let lastDay = Calendar.current.date(byAdding: .day, value: 90, to: now)
            ?? now.addingTimeInterval(90 * 24 * 60 * 60)
        let maximumDate = Calendar.current.date(
            bySettingHour: 20,
            minute: 59,
            second: 0,
            of: lastDay
        ) ?? lastDay
        let proposedDate = currentDate ?? now.addingTimeInterval(24 * 60 * 60)
        let clampedDate = min(max(proposedDate, minimumDate), maximumDate)
        self.minimumReminderDate = minimumDate
        self.maximumReminderDate = maximumDate
        _selectedDate = State(
            initialValue: CommitmentReminderScheduler
                .adjustedToAllowedReminderHours(clampedDate)
        )
        self.onSave = onSave
        self.onUseAI = onUseAI
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("다음 만남 바꾸기")
                    .font(.whisperNavigationTitle)
                    .foregroundStyle(Color.whisperTextPrimary)

                Text("기본 시간은 기록의 내용과 최근 만남을 보고 AI가 정해요. 필요할 때만 바꿔도 괜찮아요.")
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .lineSpacing(3)
            }

            DatePicker(
                "날짜와 시간",
                selection: reminderDateBinding,
                in: minimumReminderDate...maximumReminderDate
            )
            .datePickerStyle(.compact)
            .font(.whisperBodyEmphasis)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .accessibilityIdentifier("detail.reminderDatePicker")

            Label("알림은 오전 9시부터 오후 9시 사이에만 도착해요.", systemImage: "moon.stars")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)

            Button("이 시간으로 바꾸기") {
                onSave(selectedDate)
                dismiss()
            }
            .buttonStyle(.whisperPrimary(size: .compact))
            .accessibilityIdentifier("detail.saveReminderButton")

            Button("AI에게 다시 맡기기") {
                onUseAI()
                dismiss()
            }
            .font(.whisperControl)
            .foregroundStyle(Color.whisperTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: {
                let adjustedDate = CommitmentReminderScheduler
                    .adjustedToAllowedReminderHours($0)
                selectedDate = min(adjustedDate, maximumReminderDate)
            }
        )
    }
}
