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
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .calm: "leaf.fill"
        case .joy: "sun.max.fill"
        case .proud: "sparkles"
        case .excitement: "heart.fill"
        case .tired: "cloud.fill"
        case .anxiety: "wind"
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
                
                ForEach(WhisperEmotion.allCases) { emotion in
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
            .scrollContentBackground(.hidden)
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
            Image(systemName: systemImage)
                .foregroundStyle(Color.whisperAccent)
                .frame(width: 24)
            
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
