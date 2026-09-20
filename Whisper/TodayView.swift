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
    @State private var isQuickRecordPresented = false
    @State private var recordDraft = RecordDraft()
    @State private var isSaveFeedbackVisible = false
    @State private var feedbackTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: WhisperSpacing.xLarge) {
                    header

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

    private var emptyTimeline: some View {
        VStack(spacing: WhisperSpacing.small) {
            Image.whisperFlame
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 61)
                .accessibilityHidden(true)

            Text("아직 남긴 순간이 없어요")
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)

            Text("지금의 감정이나 있었던 일을 짧게 남겨보세요.")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
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

#Preview {
    NavigationStack {
        TodayView(recordStore: RecordStore(isStoredInMemoryOnly: true))
    }
}
