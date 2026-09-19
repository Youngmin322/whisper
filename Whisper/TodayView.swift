//
//  TodayView.swift
//  Whisper
//

import SwiftUI
import UIKit

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
                VStack(alignment: .leading, spacing: WhisperSpacing.large) {
                    header
                    heroCard
                    recordButton
                    momentsSection
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
        VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
            Text(Date.now.whisperDayDescription)
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)

            Text("오늘의 순간")
                .font(.whisperScreenTitle)
                .foregroundStyle(Color.whisperTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCard: some View {
        VStack(spacing: WhisperSpacing.xSmall) {
            ZStack {
                Circle()
                    .fill(Color.whisperAccent.opacity(0.08))
                    .frame(width: 168, height: 168)

                Circle()
                    .stroke(Color.whisperAccent.opacity(isSaveFeedbackVisible ? 0.28 : 0), lineWidth: 3)
                    .frame(width: 184, height: 184)
                    .blur(radius: isSaveFeedbackVisible ? 7 : 0)
                    .scaleEffect(isSaveFeedbackVisible ? 1 : 0.88)

                WhisperJarAnimation(size: .small)
                    .scaleEffect(isSaveFeedbackVisible ? 1.08 : 1)
            }
            .frame(height: 184)

            Text(heroTitle)
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)

            Text(heroSubtitle)
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WhisperSpacing.large)
        .padding(.vertical, 22)
        .background(
            LinearGradient(
                colors: [
                    Color.whisperSurfaceHighlight.opacity(0.72),
                    Color.whisperSurfaceHighlight
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: WhisperRadius.card, style: .continuous)
        )
        .animation(reduceMotion ? nil : .spring(duration: 0.42, bounce: 0.18), value: isSaveFeedbackVisible)
        .accessibilityElement(children: .combine)
    }

    private var recordButton: some View {
        Button {
            isQuickRecordPresented = true
        } label: {
            Text("순간 남기기")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 25))
        .controlSize(.large)
        .accessibilityIdentifier("home.recordButton")
    }

    private var momentsSection: some View {
        VStack(alignment: .leading, spacing: WhisperSpacing.small) {
            HStack {
                Text("오늘의 조각")
                    .font(.whisperSectionTitle)
                    .foregroundStyle(Color.whisperTextPrimary)

                Spacer()

                if !todayMoments.isEmpty {
                    Text("\(todayMoments.count)개")
                        .font(.whisperMetadata)
                        .foregroundStyle(Color.whisperTextSecondary)
                }
            }

            if todayMoments.isEmpty {
                emptyMomentsCard
            } else {
                LazyVStack(spacing: WhisperSpacing.xSmall) {
                    ForEach(todayMoments) { moment in
                        momentCard(moment)
                    }
                }
            }
        }
    }

    private var emptyMomentsCard: some View {
        VStack(spacing: WhisperSpacing.xSmall) {
            Text("한 문장이나 사진 한 장이면 충분해요.")
                .font(.whisperBody)
                .foregroundStyle(Color.whisperTextSecondary)
            Text("5초만 써도 오늘에 남아요")
                .font(.whisperCaption)
                .foregroundStyle(Color.whisperTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(
            Color.whisperSurfaceSubtle,
            in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
        )
    }

    private func momentCard(_ moment: WhisperRecord) -> some View {
        HStack(alignment: .top, spacing: WhisperSpacing.small) {
            Image(systemName: moment.photoData == nil ? "text.alignleft" : "photo.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.whisperAccent)
                .frame(width: 32, height: 32)
                .background(Color.whisperSurfaceHighlight, in: Circle())

            VStack(alignment: .leading, spacing: WhisperSpacing.xxSmall) {
                Text(moment.content)
                    .font(.whisperBody)
                    .foregroundStyle(Color.whisperTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(3)

                Text("\(moment.createdAt.whisperTimeDescription) · \(moment.photoData == nil ? "한 줄" : "사진")")
                    .font(.whisperCaption)
                    .foregroundStyle(Color.whisperTextSecondary)
            }
        }
        .padding(WhisperSpacing.medium)
        .background(
            Color.whisperSurfaceSubtle,
            in: RoundedRectangle(cornerRadius: WhisperRadius.large, style: .continuous)
        )
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
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var latestMoment: WhisperRecord? {
        todayMoments.first
    }

    private var heroTitle: String {
        if isSaveFeedbackVisible {
            return "오늘에 담았어요"
        }
        guard !todayMoments.isEmpty else {
            return "아직 비어 있어도 괜찮아요"
        }
        return todayMoments.count == 1
            ? "첫 번째 순간을 담았어요"
            : "\(todayMoments.count)개의 순간을 담았어요"
    }

    private var heroSubtitle: String {
        guard let latestMoment else {
            return "오늘 마음에 남는 순간 하나면 충분해요"
        }
        if isSaveFeedbackVisible {
            return "\(todayMoments.count)번째 순간 · \(latestMoment.createdAt.whisperTimeDescription)"
        }
        return "필요할 때 언제든 이어서 남길 수 있어요"
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
