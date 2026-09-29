//
//  EmotionPickerView.swift
//  Whisper
//

import SwiftUI
import WhisperDesignSystem

enum WhisperEmotion: String, CaseIterable, Identifiable {
    case calm = "평온"
    case joy = "기쁨"
    case proud = "뿌듯함"
    case excitement = "설렘"
    case tired = "지침"
    case anxiety = "불안"
    case depression = "우울"
    case anger = "분노"
    case sadness = "슬픔"

    static let selectableCases: [WhisperEmotion] = [
        .joy, .calm, .anxiety, .depression, .anger, .sadness
    ]

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .calm: "😌"
        case .joy: "😄"
        case .proud: "😎"
        case .excitement: "🥰"
        case .tired: "😴"
        case .anxiety: "😟"
        case .depression: "😔"
        case .anger: "😠"
        case .sadness: "😢"
        }
    }

    var systemImage: String {
        switch self {
        case .calm: "leaf.fill"
        case .joy: "sun.max.fill"
        case .proud: "sparkles"
        case .excitement: "heart.fill"
        case .tired: "cloud.fill"
        case .anxiety: "wind"
        case .depression: "cloud.rain.fill"
        case .anger: "flame.fill"
        case .sadness: "drop.fill"
        }
    }
}

struct EmotionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmotion: String?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedEmotion = nil
                    dismiss()
                } label: {
                    emotionRow(title: "선택 안 함", systemImage: "circle.dashed")
                }

                ForEach(WhisperEmotion.selectableCases) { emotion in
                    Button {
                        selectedEmotion = emotion.rawValue
                        dismiss()
                    } label: {
                        emotionRow(
                            title: emotion.rawValue,
                            systemImage: emotion.systemImage
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("지금의 감정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func emotionRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            if title == "선택 안 함" {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.whisperAccent)
                    .frame(width: 32, height: 36)
            } else {
                FlameCharacter(emotion: title, size: 32)
            }

            Text(title)
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)

            Spacer()

            if selectedEmotion == (title == "선택 안 함" ? nil : title) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.whisperAccent)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct EmotionPickerPreview: View {
    @State private var emotion: String? = WhisperEmotion.calm.rawValue

    var body: some View {
        EmotionPickerView(selectedEmotion: $emotion)
    }
}

#Preview { EmotionPickerPreview() }
