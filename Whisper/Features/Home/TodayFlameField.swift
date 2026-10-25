import SwiftUI

struct TodayFlameField: View {
    let records: [WhisperRecord]
    let collectionStartedAt: Date?
    let onSelect: (UUID) -> Void
    var reduceMotionOverride: Bool? = nil
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var motion = FlameFieldMotion()
    @State private var isVisible = false

    private var reduceMotion: Bool { reduceMotionOverride ?? systemReduceMotion }

    private var participants: [FlameMotionParticipant] {
        records.map { FlameMotionParticipant(id: $0.id, kind: FlameMotionKind.resolve($0.emotion),
                                            createdAt: $0.createdAt.timeIntervalSinceReferenceDate) }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: collectionStartedAt == nil ? 1.0 / 30.0 : 1.0 / 60.0,
                                paused: reduceMotion || isPaused || !isVisible || scenePhase != .active)) { timeline in
            GeometryReader { geometry in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let motionTime = collectionStartedAt?.timeIntervalSinceReferenceDate ?? now
                let collection = FlameCollectionMotion(count: records.count)
                let elapsed = reduceMotion ? collection.duration : timeline.date.timeIntervalSince(collectionStartedAt ?? timeline.date)
                let jar = FlameCollectionJar(layout: FlameCollectionJarLayout(size: geometry.size),
                                             motion: collection, elapsed: elapsed)

                ZStack {
                    if collectionStartedAt != nil { jar.back }

                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        if let pose = motion.pose(for: record.id, at: motionTime,
                                                  size: geometry.size, reduceMotion: reduceMotion) {
                            let flight = collectionStartedAt.map { _ in
                                collection.flight(at: elapsed, index: index, from: pose.groundPosition, jar: jar.layout)
                            }
                            let point = flight?.position ?? pose.groundPosition

                            if !reduceMotion && collectionStartedAt == nil && pose.dustOpacity > 0 {
                                landingDust(pose)
                                    .position(
                                        x: point.x - pose.facing * 15,
                                        y: point.y + 24
                                    )
                            }

                            Button { onSelect(record.id) } label: {
                                AnimatedFlameCharacter(emotion: record.emotion,
                                                       pose: releasedPose(pose, amount: flight?.release ?? 0),
                                                       shadowOpacity: Double(1 - (flight?.release ?? 0)))
                                    .scaleEffect(x: flight?.scaleX ?? 1, y: flight?.scaleY ?? 1)
                                    .rotationEffect(.degrees(flight?.rotation ?? 0))
                            }
                            .buttonStyle(.plain)
                            .frame(width: 72, height: 72)
                            .contentShape(Rectangle())
                            .position(point)
                            .opacity(flight?.opacity ?? 1)
                            .disabled(collectionStartedAt != nil)
                            .accessibilityLabel(String(localized: "\(WhisperEmotion.displayName(for: record.emotion) ?? String(localized: "감정 미선택", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale)) 불꽃, \(record.content), 순간 열기", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
                            .accessibilityIdentifier("home.flame.\(record.id.uuidString)")
                        }
                    }

                    if collectionStartedAt != nil {
                        jar.front
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onChange(of: timeline.date) { _, date in
                    let time = date.timeIntervalSinceReferenceDate
                    if collectionStartedAt == nil, let nextEvent = motion.nextEventAt, nextEvent <= time {
                        motion.advance(to: time, size: geometry.size)
                    }
                }
                .onChange(of: participants, initial: true) { _, participants in
                    motion.updateParticipants(participants, at: Date.now.timeIntervalSinceReferenceDate,
                                              size: geometry.size)
                    updatePlayback()
                }
                .onAppear {
                    isVisible = true
                    updatePlayback()
                }
                .onDisappear {
                    isVisible = false
                    updatePlayback()
                }
            }
        }
        .onChange(of: reduceMotion) { _, _ in updatePlayback() }
        .onChange(of: isPaused) { _, _ in updatePlayback() }
        .onChange(of: scenePhase) { _, _ in updatePlayback() }
        .onChange(of: collectionStartedAt) { _, _ in updatePlayback() }
    }

    private func updatePlayback() {
        let time = Date.now.timeIntervalSinceReferenceDate
        if isVisible && !isPaused && !reduceMotion && scenePhase == .active && collectionStartedAt == nil {
            motion.resume(at: time)
        } else {
            motion.pause(at: collectionStartedAt?.timeIntervalSinceReferenceDate ?? time)
        }
    }

    private func releasedPose(_ pose: FlameHopPose, amount: CGFloat) -> FlameHopPose {
        let remaining = 1 - amount
        return FlameHopPose(
            groundPosition: pose.groundPosition, frameIndex: pose.frameIndex,
            lift: pose.lift * remaining - 1.5 * amount, lead: pose.lead * remaining,
            faceRotation: pose.faceRotation * Double(remaining), dustOpacity: 0,
            dustSpread: 0, shadowScale: pose.shadowScale, facing: pose.facing,
            body: pose.body, isMoving: pose.isMoving, referenceBlend: pose.referenceBlend * remaining
        )
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
