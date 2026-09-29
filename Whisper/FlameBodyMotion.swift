import CoreGraphics

/// Only the tip and the last part of the base deform. The face remains untouched.
struct FlameBodyPose: Equatable {
    var tipBend: CGFloat = 0
    var footPush: CGFloat = 0
    var baseCompression: CGFloat = 0
    var rotation: Double = 0
    var uniformScale: CGFloat = 1

    static let rest = Self()
}

enum FlameMotionKind: String, CaseIterable {
    case joy, calm, anxiety, depression, anger, sadness

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
    let pathDuration: Double
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
            .init(stepDuration: 0.66, stepsPerBurst: 3, pauseDuration: 0.28, pathDuration: 44,
                  lift: 5.4, lead: 3.5, tipBend: 0, rotation: 0,
                  footPush: 0.045, compression: 0.09, dust: 0.24)
        case .calm:
            .init(stepDuration: 2.1, stepsPerBurst: 2, pauseDuration: 0.35, pathDuration: 76,
                  lift: 3.1, lead: 0.8, tipBend: 0.035, rotation: 2,
                  footPush: 0, compression: 0, dust: 0)
        case .anxiety:
            .init(stepDuration: 0.48, stepsPerBurst: 2, pauseDuration: 0.65, pathDuration: 62,
                  lift: 1.7, lead: 2.1, tipBend: 0.07, rotation: 5,
                  footPush: 0.035, compression: 0.035, dust: 0.06)
        case .depression:
            .init(stepDuration: 1.45, stepsPerBurst: 1, pauseDuration: 1.05, pathDuration: 120,
                  lift: 0.8, lead: 0.7, tipBend: 0.025, rotation: 1,
                  footPush: 0, compression: 0.055, dust: 0)
        case .anger:
            .init(stepDuration: 0.45, stepsPerBurst: 2, pauseDuration: 0.34, pathDuration: 39,
                  lift: 6.5, lead: 4.5, tipBend: 0.13, rotation: 13,
                  footPush: 0.07, compression: 0.11, dust: 0.28)
        case .sadness:
            .init(stepDuration: 1.6, stepsPerBurst: 1, pauseDuration: 0.75, pathDuration: 105,
                  lift: 1.3, lead: 0.8, tipBend: 0.075, rotation: 2.5,
                  footPush: 0.006, compression: 0.02, dust: 0)
        }
    }
}

enum FlameBodyMotion {
    static func sample(kind: FlameMotionKind, phase: Double) -> FlameBodyPose {
        let profile = FlameMotionProfile.forKind(kind)
        let p = min(1, max(0, phase))
        let travel = CGFloat(sin(.pi * p))
        let anticipation = CGFloat(max(0, sin(.pi * min(1, p / 0.4)))) * CGFloat(max(0, 1 - p / 0.55))
        let settling = CGFloat(sin(.pi * max(0, min(1, (p - 0.5) / 0.5))))

        switch kind {
        case .joy:
            return .rest
        case .calm:
            return .init(tipBend: profile.tipBend * CGFloat(sin(2 * .pi * p)),
                         rotation: profile.rotation * sin(2 * .pi * p))
        case .anxiety:
            let flutter = CGFloat(sin(6 * .pi * p)) * travel
            return .init(tipBend: profile.tipBend * flutter,
                         footPush: profile.footPush * flutter,
                         baseCompression: profile.compression * anticipation,
                         rotation: profile.rotation * Double(flutter))
        case .depression:
            return .init(tipBend: -profile.tipBend * travel,
                         baseCompression: profile.compression * settling,
                         rotation: -profile.rotation * Double(travel))
        case .anger:
            let jab = CGFloat(sin(2 * .pi * p))
            return .init(tipBend: profile.tipBend * jab,
                         footPush: profile.footPush * anticipation,
                         baseCompression: profile.compression * anticipation,
                         rotation: -profile.rotation * Double(jab),
                         uniformScale: 1 + 0.02 * travel)
        case .sadness:
            let delayed = CGFloat(max(0, sin(.pi * max(0, p - 0.18) / 0.82)))
            return .init(tipBend: -profile.tipBend * delayed,
                         footPush: -profile.footPush * settling,
                         baseCompression: profile.compression * settling,
                         rotation: -profile.rotation * Double(delayed))
        }
    }
}
