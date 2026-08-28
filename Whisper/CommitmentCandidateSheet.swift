//
//  CommitmentCandidateSheet.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

struct CommitmentCandidateSheet: View {
    let candidate: CommitmentCandidate
    let onRemember: (Date?) -> Void
    let onDismiss: () -> Void
    @State private var planningAnchor = Date.now
    @State private var customReminderDate: Date?
    @State private var isEditingReminderTime = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    WhisperJar(size: .small)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("이 마음을 기억해 둘까요?")
                            .font(.whisperNavigationTitle)
                            .foregroundStyle(Color.whisperTextPrimary)

                        Text("잊힐 만한 간격으로 Whisper가 다시 건넬게요.")
                            .font(.whisperBody)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(candidate.name)
                        .font(.whisperBodyEmphasis)
                        .foregroundStyle(Color.whisperAccentText)

                    Text("“\(candidate.quote)”")
                        .font(.whisperBodyLarge)
                        .foregroundStyle(Color.whisperTextPrimary)
                        .lineSpacing(5)
                        .lineLimit(5)

                    if !candidate.topics.isEmpty {
                        Text(candidate.topics.map { "#\($0)" }.joined(separator: "  "))
                            .font(.whisperCaption)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .whisperCardStyle(
                    fill: .whisperSurfaceSubtle,
                    border: .whisperBorderSubtle,
                    cornerRadius: WhisperRadius.large
                )

                reminderTimeCard

                Button("응, 이때 다시 건네줘") {
                    onRemember(displayedReminderDate)
                }
                .buttonStyle(.whisperPrimary(size: .compact))
                .accessibilityIdentifier("commitment.rememberButton")

                Button("이번에는 괜찮아요", action: onDismiss)
                    .font(.whisperControl)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, WhisperLayout.sheetHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("commitment.candidateSheet")
    }

    private var reminderTimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    customReminderDate == nil ? "AI가 정한 다음 만남" : "내가 정한 다음 만남",
                    systemImage: customReminderDate == nil ? "sparkles" : "calendar"
                )
                .font(.whisperControl)
                .foregroundStyle(Color.whisperAccentText)

                Spacer()

                Button(customReminderDate == nil ? "바꾸기" : "AI에게 맡기기") {
                    if customReminderDate == nil {
                        isEditingReminderTime.toggle()
                    } else {
                        customReminderDate = nil
                        isEditingReminderTime = false
                    }
                }
                .font(.whisperCaption)
                .accessibilityIdentifier("commitment.changeReminderButton")
            }

            Text(displayedReminderDate.whisperDateTimeDescription)
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)
                .accessibilityIdentifier("commitment.reminderDate")

            if isEditingReminderTime {
                DatePicker(
                    "날짜와 시간",
                    selection: reminderDateBinding,
                    in: minimumReminderDate...maximumReminderDate
                )
                .datePickerStyle(.compact)
                .font(.whisperBody)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .accessibilityIdentifier("commitment.reminderDatePicker")
            }

            Text("알림은 오전 9시부터 오후 9시 사이에만 도착해요.")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
        }
        .padding(14)
        .whisperCardStyle(
            fill: .whisperSurfaceDefault,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.medium
        )
    }

    private var aiSuggestedReminderDate: Date {
        let offset = candidate.reminderTiming.offsetsInHours.first ?? 24
        let date = planningAnchor.addingTimeInterval(TimeInterval(offset * 60 * 60))
        let adjustedDate = CommitmentReminderScheduler.adjustedToAllowedReminderHours(date)
        return min(adjustedDate, maximumReminderDate)
    }

    private var displayedReminderDate: Date {
        customReminderDate ?? aiSuggestedReminderDate
    }

    private var minimumReminderDate: Date {
        planningAnchor.addingTimeInterval(60 * 60)
    }

    private var maximumReminderDate: Date {
        let lastDay = Calendar.current.date(byAdding: .day, value: 90, to: planningAnchor)
            ?? planningAnchor.addingTimeInterval(90 * 24 * 60 * 60)
        return Calendar.current.date(
            bySettingHour: 20,
            minute: 59,
            second: 0,
            of: lastDay
        ) ?? lastDay
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { customReminderDate ?? aiSuggestedReminderDate },
            set: {
                let adjustedDate = CommitmentReminderScheduler
                    .adjustedToAllowedReminderHours($0)
                customReminderDate = min(adjustedDate, maximumReminderDate)
            }
        )
    }
}
