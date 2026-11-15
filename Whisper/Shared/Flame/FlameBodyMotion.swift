import CoreGraphics

/// Only the tip and the last part of the base deform. The face remains untouched.
struct FlameBodyPose: Equatable {
    var tipBend: CGFloat = 0
    var footPush: CGFloat = 0
    var baseCompression: CGFloat = 0
    var rotation: Double = 0
    var uniformScale: CGFloat = 1
    /// Volume-preserving squash (< 0) and stretch (> 0) around the base. The face follows it.
    var stretch: CGFloat = 0

    static let rest = Self()

    func faded(by amount: CGFloat) -> Self {
        .init(tipBend: tipBend * amount, footPush: footPush * amount,
              baseCompression: baseCompression * amount, rotation: rotation * Double(amount),
              uniformScale: 1 + (uniformScale - 1) * amount, stretch: stretch * amount)
    }
}

enum FlameMotionKind: String, CaseIterable {
    case joy, calm, anxiety, depression, anger, sadness

    /// Joy keeps its approved asymmetric artwork; the others mirror to face their travel.
    var mirrorsArtwork: Bool { self != .joy }

    static func resolve(_ emotion: String?) -> Self {
        switch emotion ?? "" {
        case WhisperEmotion.calm.rawValue, "차분함": .calm
        case WhisperEmotion.anxiety.rawValue: .anxiety
        case WhisperEmotion.depression.rawValue, WhisperEmotion.tired.rawValue: .depression
        case WhisperEmotion.anger.rawValue: .anger
        case WhisperEmotion.sadness.rawValue, "속상": .sadness
        default: .joy
        }
    }
}

struct FlameMotionProfile {
    let stepDuration: Double
    let stepsPerBurst: Int
    let pauseDuration: Double
    let stepDistance: CGFloat
    let lift: CGFloat
    let lead: CGFloat
    let tipBend: CGFloat
    let rotation: Double
    let footPush: CGFloat
    let compression: CGFloat
    let dust: Double

    static func forKind(_ kind: FlameMotionKind) -> Self {
        switch kind {
        case .joy:
            .init(stepDuration: 0.72, stepsPerBurst: 2, pauseDuration: 6, stepDistance: 26,
                  lift: 11, lead: 0, tipBend: 0.075, rotation: 18,
                  footPush: 0, compression: 0, dust: 0.24)
        case .calm:
            .init(stepDuration: 2.1, stepsPerBurst: 1, pauseDuration: 8, stepDistance: 24,
                  lift: 9, lead: 0, tipBend: 0.035, rotation: 4,
                  footPush: 0, compression: 0, dust: 0)
        case .anxiety:
            .init(stepDuration: 0.48, stepsPerBurst: 2, pauseDuration: 8.5, stepDistance: 12,
                  lift: 5, lead: 0, tipBend: 0.07, rotation: 6,
                  footPush: 0, compression: 0, dust: 0.06)
        case .depression:
            .init(stepDuration: 1.45, stepsPerBurst: 1, pauseDuration: 11, stepDistance: 12,
                  lift: 3, lead: 0, tipBend: 0.025, rotation: 3,
                  footPush: 0, compression: 0, dust: 0)
        case .anger:
            .init(stepDuration: 0.5, stepsPerBurst: 2, pauseDuration: 6.5, stepDistance: 30,
                  lift: 9, lead: 0, tipBend: 0.11, rotation: 22,
                  footPush: 0, compression: 0, dust: 0.28)
        case .sadness:
            .init(stepDuration: 1.6, stepsPerBurst: 1, pauseDuration: 9, stepDistance: 16,
                  lift: 4, lead: 0, tipBend: 0.06, rotation: 4,
                  footPush: 0, compression: 0, dust: 0)
        }
    }
}
