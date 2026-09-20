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
    @State private var isDetailRecordPresented = false
    @State private var shouldOpenDetailAfterSheetDismisses = false
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
                        dayCompletionSection
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
        .background(Color.whisperBackground)
        .navigationBarHidden(true)
        .sheet(
            isPresented: $isQuickRecordPresented,
            onDismiss: openDetailAfterSheetDismissesIfNeeded
        ) {
            QuickRecordView(
                draft: $recordDraft,
                onSave: { saveMoment() },
                onOpenDetail: {
                    shouldOpenDetailAfterSheetDismisses = true
                }
            )
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(WhisperRadius.sheet)
        }
        .navigationDestination(isPresented: $isDetailRecordPresented) {
            DetailedRecordView(draft: $recordDraft) { emotion, photoData in
                saveMoment(emotion: emotion, photoData: photoData)
            }
        }
        .onDisappear {
            feedbackTask?.cancel()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: WhisperSpacing.medium) {
            VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                Text(Date.now.whisperDayDescription)
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)

                Text("오늘의 순간")
                    .font(.whisperScreenTitle)
                    .foregroundStyle(Color.whisperTextPrimary)
            }

            Spacer(minLength: WhisperSpacing.small)

            if !todayMoments.isEmpty {
                VStack(alignment: .trailing, spacing: WhisperSpacing.xxSmall) {
                    Text("\(todayMoments.count)개의 순간")
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextSecondary)

                    Button {
                        isQuickRecordPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("순간 더 남기기")
                    .accessibilityIdentifier("home.addMomentButton")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyTimeline: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.large) {
            Text("오늘의 타임라인")
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            VStack(spacing: WhisperSpacing.small) {
                Image.whisperFlame
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 61)
                    .accessibilityHidden(true)

                Text("아직 남긴 순간이 없어요")
                    .font(.whisperBodyEmphasis)
                    .foregroundStyle(Color.whisperTextPrimary)

                Text("오늘 마음에 남은 한 가지부터 시작해보세요.")
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 340)

            Button {
                isQuickRecordPresented = true
            } label: {
                Text("첫 순간 남기기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.whisperPrimary)
            .accessibilityIdentifier("home.recordButton")
        }
    }

    private var momentsTimeline: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.medium) {
            Text("오늘 남긴 순간")
                .font(.whisperSectionTitle)
                .foregroundStyle(Color.whisperTextPrimary)

            VStack(spacing: 0) {
                ForEach(Array(todayMoments.enumerated()), id: \.element.id) { index, moment in
                    timelineRow(
                        moment,
                        showsContinuation: index < todayMoments.count - 1
                    )
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var dayCompletionSection: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.large) {
            Divider()

            HStack(alignment: .center, spacing: WhisperSpacing.large) {
                VStack(alignment: .leading, spacing: WhisperSpacing.xSmall) {
                    Text("오늘 \(todayMoments.count)개의 순간")
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextSecondary)

                    Text(completionPrompt)
                        .font(.whisperNavigationTitle)
                        .foregroundStyle(Color.whisperTextPrimary)

                    Text(completionNote)
                        .font(.whisperCaption)
                        .foregroundStyle(Color.whisperTextSecondary)
                }

                Spacer(minLength: 0)
                WhisperJarAnimation(size: .home)
            }

            if let journal = recordStore.journal(on: .now) {
                NavigationLink {
                    JournalDetailView(journal: journal, recordStore: recordStore)
                } label: {
                    Text("오늘의 일기 보기")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.whisperPrimary)
                .accessibilityIdentifier("home.openJournalButton")
            } else {
                NavigationLink {
                    JournalFlowView(recordStore: recordStore)
                } label: {
                    Text("\(todayMoments.count)개의 순간으로 일기 만들기")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.whisperPrimary)
                .accessibilityIdentifier("home.reviewJournalButton")
            }
        }
    }

    private var saveToast: some View {
        Label("오늘에 담았어요", systemImage: "sparkle")
            .font(.whisperControl)
            .foregroundStyle(Color.whisperTextPrimary)
            .padding(.horizontal, WhisperSpacing.medium)
            .padding(.vertical, WhisperSpacing.small)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: Color.black.opacity(0.14), radius: 20, y: 8)
            .accessibilityIdentifier("home.saveFeedback")
    }

    private var todayMoments: [WhisperRecord] {
        recordStore.records(on: .now)
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var completionPrompt: String {
        recordStore.journal(on: .now) == nil
            ? "이 순간들로 오늘을\n한 편의 일기로 남길까요?"
            : "오늘의 일기가\n안전하게 저장되어 있어요"
    }

    private var completionNote: String {
        recordStore.journal(on: .now) == nil
            ? "나중에 만들어도 오늘의 순간은 그대로 남아 있어요"
            : "언제든 다시 읽거나 수정할 수 있어요"
    }

    private func saveMoment(
        emotion: String? = nil,
        photoData: Data? = nil
    ) -> Bool {
        let content = recordDraft.contentForSaving
        guard !content.isEmpty else { return false }

        guard recordStore.add(
            title: recordDraft.titleForSaving,
            content: content,
            emotion: emotion,
            photoData: photoData
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

    private func openDetailAfterSheetDismissesIfNeeded() {
        guard shouldOpenDetailAfterSheetDismisses else { return }
        shouldOpenDetailAfterSheetDismisses = false
        isDetailRecordPresented = true
    }
}

#Preview {
    NavigationStack {
        TodayView(recordStore: RecordStore(isStoredInMemoryOnly: true))
    }
}
