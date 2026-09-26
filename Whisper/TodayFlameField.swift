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
                ZStack {
                    ForEach(records) { record in
                        let seed = Self.seed(for: record.id)
                        let travel = point(for: seed, time: now, in: geometry.size)
                        let progress = collectionProgress(at: timeline.date)
                        let jarPoint = CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 65)
                        let point = CGPoint(
                            x: travel.point.x + (jarPoint.x - travel.point.x) * progress,
                            y: travel.point.y + (jarPoint.y - travel.point.y) * progress
                        )

                        if !reduceMotion && progress == 0 {
                            dust(for: seed, phase: travel.phase, facing: travel.facing)
                                .position(x: point.x - travel.facing * 21, y: point.y + 22)
                        }

                        Button { onSelect(record.id) } label: {
                            FlameCharacter(emotion: record.emotion, size: 48)
                                .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(travel.facing) * 14), axis: (x: 0, y: 1, z: 0))
                                .rotationEffect(.degrees(reduceMotion ? 0 : Double(travel.facing) * 7))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 72, height: 72)
                        .contentShape(Rectangle())
                        .position(point)
                        .opacity(progress > 0.9 ? 1 - (progress - 0.9) * 10 : 1)
                        .disabled(progress > 0)
                        .accessibilityLabel("\(record.emotion ?? "감정 미선택") 불꽃, \(record.content), 순간 열기")
                        .accessibilityIdentifier("home.flame.\(record.id.uuidString)")
                    }

                    if collectionStartedAt != nil {
                        FlameBottle(emotion: representativeEmotion, width: 80)
                            .position(x: geometry.size.width / 2, y: geometry.size.height - 65)
                            .accessibilityHidden(true)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private var representativeEmotion: String? {
        records.reversed().compactMap(\.emotion).first
    }

    private func collectionProgress(at date: Date) -> CGFloat {
        guard let collectionStartedAt else { return 0 }
        if reduceMotion { return 1 }
        let elapsed = date.timeIntervalSince(collectionStartedAt)
        let fraction = min(1, max(0, elapsed / 0.75))
        return CGFloat(1 - pow(1 - fraction, 3))
    }

    private func dust(for seed: Double, phase: Double, facing: CGFloat) -> some View {
        let opacity = max(0, 1 - min(phase, 1 - phase) * 8)
        return HStack(spacing: 5) {
            Circle().frame(width: 4, height: 4)
            Circle().frame(width: 2, height: 2).offset(y: 4)
        }
        .foregroundStyle(Color(red: 0.86, green: 0.68, blue: 0.53))
        .opacity(opacity * (0.45 + seed * 0.25))
        .scaleEffect(x: facing)
        .accessibilityHidden(true)
    }

    private func point(for seed: Double, time: TimeInterval, in size: CGSize) -> (point: CGPoint, facing: CGFloat, phase: Double) {
        let width = max(1, size.width - 88)
        let height = max(1, size.height - 96)
        guard !reduceMotion else {
            return (CGPoint(x: 44 + width * CGFloat(seed), y: 48 + height * CGFloat(Self.fraction(seed * 2.3))), 1, 0)
        }
        let horizontal = Self.triangle(time / (7.5 + seed * 3) + seed)
        let vertical = Self.triangle(time / (10 + seed * 4) + seed * 1.7)
        let phase = Self.fraction(time / (0.68 + seed * 0.2) + seed)
        let facing: CGFloat = Self.fraction(time / (7.5 + seed * 3) + seed) < 0.5 ? 1 : -1
        let jump = abs(sin(phase * .pi)) * 19
        return (
            CGPoint(x: 44 + width * CGFloat(horizontal), y: 48 + height * CGFloat(vertical) - CGFloat(jump)),
            facing,
            phase
        )
    }

    private static func seed(for id: UUID) -> Double {
        let hash = id.uuidString.utf8.reduce(UInt64(1469598103934665603)) { value, byte in
            (value ^ UInt64(byte)) &* 1099511628211
        }
        return Double(hash % 10_000) / 10_000
    }

    private static func fraction(_ value: Double) -> Double {
        value - floor(value)
    }

    private static func triangle(_ value: Double) -> Double {
        let phase = fraction(value)
        return phase < 0.5 ? phase * 2 : (1 - phase) * 2
    }
}
