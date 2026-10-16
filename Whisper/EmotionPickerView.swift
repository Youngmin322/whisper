//
//  EmotionPickerView.swift
//  Whisper
//

import SwiftUI

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

    // rawValue is persisted in records and drafts; only the display name is translated.
    var displayName: String {
        switch self {
        case .calm: String(localized: "평온")
        case .joy: String(localized: "기쁨")
        case .proud: String(localized: "뿌듯함")
        case .excitement: String(localized: "설렘")
        case .tired: String(localized: "지침")
        case .anxiety: String(localized: "불안")
        case .depression: String(localized: "우울")
        case .anger: String(localized: "분노")
        case .sadness: String(localized: "슬픔")
        }
    }

    static func displayName(for storedValue: String?) -> String? {
        guard let storedValue else { return nil }
        // Older versions also persisted these two names.
        switch storedValue {
        case "차분함": return WhisperEmotion.calm.displayName
        case "속상": return WhisperEmotion.sadness.displayName
        default: return WhisperEmotion(rawValue: storedValue)?.displayName ?? storedValue
        }
    }

    static func searchText(for storedValue: String?) -> String {
        searchNames(for: storedValue).joined(separator: " ")
    }

    static func searchNames(for storedValue: String?) -> [String] {
        guard let storedValue else { return [] }
        let name = displayName(for: storedValue) ?? storedValue
        return name == storedValue ? [storedValue] : [name, storedValue]
    }

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
    var allowsEmptySelection = true

    var body: some View {
        NavigationStack {
            List {
                if allowsEmptySelection {
                    Button {
                        selectedEmotion = nil
                        dismiss()
                    } label: {
                        emotionRow(emotion: nil)
                    }
                }

                ForEach(WhisperEmotion.selectableCases) { emotion in
                    Button {
                        selectedEmotion = emotion.rawValue
                        dismiss()
                    } label: {
                        emotionRow(emotion: emotion)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "지금의 감정"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "닫기")) { dismiss() }
                }
            }
        }
    }

    private func emotionRow(emotion: WhisperEmotion?) -> some View {
        HStack(spacing: 14) {
            if emotion == nil {
                Image(systemName: "circle.dashed")
                    .foregroundStyle(Color.whisperAccent)
                    .frame(width: 32, height: 36)
            } else {
                FlameCharacter(emotion: emotion?.rawValue, size: 32)
            }

            Text(emotion?.displayName ?? String(localized: "선택 안 함"))
                .font(.whisperBodyEmphasis)
                .foregroundStyle(Color.whisperTextPrimary)

            Spacer()

            if selectedEmotion == emotion?.rawValue {
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
