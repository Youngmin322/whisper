#if DEBUG
import SwiftUI

/// Read-only motion review. Each approved character plays its own motion profile.
struct FlameMotionPreview: View {
    @State private var reduceMotion = false
    @State private var playing = true
    private let emotions = WhisperEmotion.selectableCases

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("감정별 불꽃 움직임").font(.title2.bold())
                Toggle("움직임 줄이기", isOn: $reduceMotion)
                Toggle("재생", isOn: $playing)
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !playing || reduceMotion)) { timeline in
                    let time = playing ? timeline.date.timeIntervalSinceReferenceDate : 0
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(emotions) { emotion in
                            VStack(spacing: 2) {
                                Text(emotion.rawValue).font(.headline)
                                Text(description(for: emotion))
                                    .font(.caption2)
                                    .foregroundStyle(Color.whisperTextSecondary)
                                HStack(spacing: 8) {
                                    FlameCharacter(emotion: emotion.rawValue, size: 35)
                                        .frame(width: 40, height: 92)
                                    AnimatedFlameCharacter(
                                        emotion: emotion.rawValue,
                                        pose: FlameHopMotion.sample(seed: 0, time: time,
                                                                   size: .zero, reduceMotion: reduceMotion,
                                                                   emotion: emotion.rawValue),
                                        size: 66
                                    )
                                    .frame(width: 102, height: 100)
                                }
                                Text("원본 · 움직임")
                                    .font(.caption2)
                                    .foregroundStyle(Color.whisperTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.whisperBackground)
    }

    private func description(for emotion: WhisperEmotion) -> String {
        switch emotion {
        case .joy: "빠르고 높게 총총"
        case .calm: "천천히 떠오름"
        case .anxiety: "작게 떨고 멈칫"
        case .depression: "낮게 가라앉음"
        case .anger: "짧고 날카롭게 튐"
        case .sadness: "느리고 뒤늦게 흔들림"
        default: ""
        }
    }
}

#Preview("감정별 불꽃 움직임") { FlameMotionPreview() }
#endif
