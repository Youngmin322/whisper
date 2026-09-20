//
//  TodayView.swift
//  Whisper
//

import SwiftUI
import UIKit
import WhisperDesignSystem

struct TodayView: View {
    let recordStore: RecordStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("today.dismissedUnfinishedDayKey") private var dismissedUnfinishedDayKey = ""
    @State private var isQuickRecordPresented = false
    @State private var recordDraft = RecordDraft()
    @State private var isSaveFeedbackVisible = false
    @State private var feedbackTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: WhisperSpacing.xLarge) {
                    header

                    dailyJarHero

                    if let unfinishedYesterday {
                        unfinishedYesterdayCard(unfinishedYesterday)
                    }

                    if todayMoments.isEmpty {
                        emptyTimeline
                    } else {
                        momentsTimeline
                    }
                }
                .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
                .padding(.top, WhisperSpacing.small)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)

            if isSaveFeedbackVisible {
                saveToast
                    .padding(.bottom, WhisperSpacing.large)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            recordButton
        }
        .background(Color.whisperBackground)
        .navigationBarHidden(true)
        .sheet(isPresented: $isQuickRecordPresented) {
            QuickRecordView(
                draft: $recordDraft,
                onSave: { saveMoment() }
            )
            .presentationDetents([.fraction(0.62), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(WhisperRadius.sheet)
        }
        .onDisappear {
            feedbackTask?.cancel()
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: WhisperSpacing.medium) {
                headerTitle
                Spacer(minLength: WhisperSpacing.small)
                journalAction
            }

            VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
                headerTitle
                journalAction
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
            Text(Date.now.whisperDayDescription)
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)

            Text("오늘의 순간")
                .font(.whisperScreenTitle)
                .foregroundStyle(Color.whisperTextPrimary)
        }
    }

    @ViewBuilder
    private var journalAction: some View {
        if let journal = recordStore.journal(on: .now) {
            NavigationLink {
                JournalDetailView(journal: journal, recordStore: recordStore)
            } label: {
                Text("오늘 일기 보기")
            }
            .buttonStyle(.whisperSecondary)
            .accessibilityIdentifier("home.openJournalButton")
        } else {
            NavigationLink {
                JournalFlowView(recordStore: recordStore)
            } label: {
                Text("오늘 일기 정리")
            }
            .buttonStyle(.whisperSecondary)
            .accessibilityIdentifier("home.reviewJournalButton")
        }
    }

    private var recordButton: some View {
        Button {
            isQuickRecordPresented = true
        } label: {
            Label("순간 남기기", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.whisperPrimary)
        .accessibilityIdentifier("home.recordButton")
        .padding(.horizontal, WhisperLayout.screenHorizontalPadding)
        .padding(.vertical, WhisperSpacing.small)
        .background(Color.whisperBackground)
    }

    private var dailyJarHero: some View {
        HStack(alignment: .center, spacing: WhisperSpacing.medium) {
            VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                Text(jarEyebrow)
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperAccentText)

                Text(jarTitle)
                    .font(.whisperNavigationTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(jarDescription)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WhisperJarAnimation(size: .today)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
        .padding(.leading, WhisperSpacing.large)
        .padding(.trailing, WhisperSpacing.small)
        .padding(.vertical, WhisperSpacing.xSmall)
        .background(
            Color.whisperSurfaceHighlight,
            in: RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.jarHero")
    }

    private func unfinishedYesterdayCard(_ day: UnfinishedYesterday) -> some View {
        HStack(spacing: WhisperSpacing.xSmall) {
            NavigationLink {
                JournalFlowView(recordStore: recordStore, date: day.date)
            } label: {
                HStack(spacing: WhisperSpacing.small) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.whisperAccentText)
                        .frame(width: 32, height: 32)
                        .background(Color.whisperSurfaceDefault, in: Circle())

                    VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                        Text("어제의 기록을 정리할까요?")
                            .font(.whisperBodyEmphasis)
                            .foregroundStyle(Color.whisperTextPrimary)

                        Text("남겨둔 순간 \(day.count)개가 있어요")
                            .font(.whisperCaption)
                            .foregroundStyle(Color.whisperTextSecondary)
                    }

                    Spacer(minLength: WhisperSpacing.xSmall)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.whisperTextSecondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.unfinishedYesterdayButton")

            Button {
                dismissedUnfinishedDayKey = day.dayKey
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.whisperTextSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("어제 기록 알림 닫기")
        }
        .padding(.leading, WhisperSpacing.medium)
        .padding(.trailing, WhisperSpacing.xxSmall)
        .padding(.vertical, WhisperSpacing.xSmall)
        .whisperCardStyle(
            fill: .whisperSurfaceHighlight,
            border: .whisperBorderSubtle,
            cornerRadius: WhisperRadius.medium
        )
    }

    private var emptyTimeline: some View {
        VStack(spacing: WhisperSpacing.small) {
            Text("아직 남긴 순간이 없어요")
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)

            Text("지금의 감정이나 있었던 일을 짧게 남겨보세요.")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .accessibilityElement(children: .combine)
    }

    private var momentsTimeline: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("오늘 남긴 순간")
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)

                Spacer()

                Text("\(todayMoments.count)개")
                    .font(.whisperMetadata)
                    .foregroundStyle(Color.whisperTextSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(todayMoments.enumerated()), id: \.element.id) { index, moment in
                    NavigationLink {
                        RecordDetailView(record: moment, recordStore: recordStore)
                    } label: {
                        timelineRow(
                            moment,
                            showsContinuation: index < todayMoments.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func timelineRow(
        _ moment: WhisperRecord,
        showsContinuation: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: WhisperSpacing.small) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.whisperAccent)
                    .frame(width: 10, height: 10)

                if showsContinuation {
                    Rectangle()
                        .fill(Color.whisperDivider)
                        .frame(width: 1)
                        .frame(minHeight: 54)
                }
            }

            VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                Text(moment.createdAt.whisperTimeDescription)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)

                Text(moment.content)
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            if moment.photoData != nil {
                Image(systemName: "photo.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.whisperAccent)
                    .accessibilityLabel("사진 포함")
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.whisperTextSecondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, WhisperSpacing.xSmall)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var saveToast: some View {
        WhisperToast("순간을 남겼어요", systemImage: "checkmark")
            .accessibilityIdentifier("home.saveFeedback")
    }

    private var todayMoments: [WhisperRecord] {
        recordStore.records(on: .now)
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var jarEyebrow: String {
        recordStore.journal(on: .now) == nil ? "오늘의 유리병" : "오늘의 일기"
    }

    private var jarTitle: String {
        if recordStore.journal(on: .now) != nil {
            return "오늘을 잘 간직했어요"
        }

        switch todayMoments.count {
        case 0:
            return "첫 순간을 기다리고 있어요"
        case 1:
            return "한 개의 순간이 담겼어요"
        default:
            return "\(todayMoments.count)개의 순간이 모였어요"
        }
    }

    private var jarDescription: String {
        if recordStore.journal(on: .now) != nil {
            return "언제든 다시 펼쳐볼 수 있어요."
        }

        return todayMoments.isEmpty
            ? "짧은 한 문장부터 시작해도 괜찮아요."
            : "하루가 끝나면 한 편의 일기로 정리해 보세요."
    }

    private var unfinishedYesterday: UnfinishedYesterday? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) else {
            return nil
        }

        let dayKey = JournalDayKey.make(for: yesterday, calendar: calendar)
        guard dismissedUnfinishedDayKey != dayKey,
              recordStore.journal(on: yesterday, calendar: calendar) == nil else {
            return nil
        }

        let count = recordStore.records(on: yesterday, calendar: calendar).count
        guard count > 0 else { return nil }
        return UnfinishedYesterday(date: yesterday, dayKey: dayKey, count: count)
    }

    private func saveMoment() -> Bool {
        let content = recordDraft.contentForSaving
        guard !content.isEmpty else { return false }

        guard recordStore.add(
            title: recordDraft.titleForSaving,
            content: content,
            emotion: nil,
            photoData: nil
        ) else {
            return false
        }

        recordDraft = RecordDraft()
        showSaveFeedback()
        return true
    }

    private func showSaveFeedback() {
        feedbackTask?.cancel()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(reduceMotion ? nil : .spring(duration: 0.36, bounce: 0.2)) {
            isSaveFeedbackVisible = true
        }

        feedbackTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    isSaveFeedbackVisible = false
                }
            }
        }
    }

}

private struct UnfinishedYesterday {
    let date: Date
    let dayKey: String
    let count: Int
}

#Preview {
    NavigationStack {
        TodayView(recordStore: RecordStore(isStoredInMemoryOnly: true))
    }
}
