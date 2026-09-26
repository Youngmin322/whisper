import SwiftUI

struct TodayFlameField: View {
    let records: [WhisperRecord]
    let collectionStartedAt: Date?
    let onSelect: (UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { geometry in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let motionTime = collectionStartedAt?.timeIntervalSinceReferenceDate ?? now
                let progress = collectionProgress(at: timeline.date)
                let jarPoint = CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 65)

                ZStack {
                    ForEach(records) { record in
                        let pose = FlameHopMotion.sample(
                            seed: FlameHopMotion.seed(for: record.id),
                            time: motionTime,
                            size: geometry.size,
                            reduceMotion: reduceMotion
                        )
                        let point = CGPoint(
                            x: pose.groundPosition.x + (jarPoint.x - pose.groundPosition.x) * progress,
                            y: pose.groundPosition.y + (jarPoint.y - pose.groundPosition.y) * progress
                        )

                        if !reduceMotion && progress == 0 && pose.dustOpacity > 0 {
                            landingDust(pose)
                                .position(
                                    x: point.x - pose.facing * 15,
                                    y: point.y + 24
                                )
                        }

                        Button { onSelect(record.id) } label: {
                            AnimatedFlameCharacter(emotion: record.emotion, pose: pose)
                                .scaleEffect(1 - progress * 0.4)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 72, height: 72)
                        .contentShape(Rectangle())
                        .position(point)
                        .opacity(progress > 0.84 ? (1 - progress) / 0.16 : 1)
                        .disabled(progress > 0)
                        .accessibilityLabel("\(record.emotion ?? "감정 미선택") 불꽃, \(record.content), 순간 열기")
                        .accessibilityIdentifier("home.flame.\(record.id.uuidString)")
                    }

                    if collectionStartedAt != nil {
                        FlameBottle(emotion: JournalDraftComposer.representativeEmotion(in: records), width: 80)
                            .position(jarPoint)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private func collectionProgress(at date: Date) -> CGFloat {
        guard let collectionStartedAt else { return 0 }
        if reduceMotion { return 1 }
        let fraction = min(1, max(0, date.timeIntervalSince(collectionStartedAt) / 0.75))
        return CGFloat(1 - pow(1 - fraction, 3))
    }

    private func landingDust(_ pose: FlameHopPose) -> some View {
        HStack(spacing: 5) {
            Circle().frame(width: 4, height: 4)
                .offset(x: -pose.dustSpread * 9, y: -pose.dustSpread * 4)
            Circle().frame(width: 3, height: 3)
                .offset(x: -pose.dustSpread * 3, y: pose.dustSpread * 2)
            Circle().frame(width: 2, height: 2)
                .offset(x: pose.dustSpread * 4, y: -pose.dustSpread * 5)
        }
        .foregroundStyle(Color(red: 0.86, green: 0.68, blue: 0.53))
        .opacity(pose.dustOpacity)
        .scaleEffect(x: pose.facing)
        .accessibilityHidden(true)
    }
}
