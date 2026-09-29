import CoreGraphics
import Foundation

struct FlameHopPose {
    let groundPosition: CGPoint
    let frameIndex: Int
    let lift: CGFloat
    let lead: CGFloat
    let faceRotation: Double
    let dustOpacity: Double
    let dustSpread: CGFloat
    let shadowScale: CGFloat
    let facing: CGFloat
    var body: FlameBodyPose = .rest
}

enum FlameHopMotion {
    static func sample(
        seed: Double,
        time: TimeInterval,
        size: CGSize,
        reduceMotion: Bool,
        emotion: String? = nil
    ) -> FlameHopPose {
        let kind = FlameMotionKind.resolve(emotion)
        let profile = FlameMotionProfile.forKind(kind)
        let stepDuration = profile.stepDuration + seed * 0.08
        let stepsPerBurst = profile.stepsPerBurst + (kind == .joy ? Int(seed * 2) : 0)
        let activeDuration = stepDuration * Double(stepsPerBurst)
        let pauseDuration = profile.pauseDuration + seed * 0.15
        let burstDuration = activeDuration + pauseDuration
        let clock = time + seed * burstDuration
        let burstIndex = floor(clock / burstDuration)
        let withinBurst = clock - burstIndex * burstDuration
        let walking = withinBurst < activeDuration
        let stepClock = withinBurst / stepDuration
        let completedSteps = floor(stepClock)
        let stepPhase = stepClock - completedSteps

        let travel: Double
        if !walking { travel = 1 }
        else if kind == .anger { travel = pow(stepPhase, 0.55) }
        else if kind == .anxiety { travel = smoothstep(stepPhase) }
        else { travel = smoothstep(stepPhase) }
        let walkingElapsed = burstIndex * activeDuration + (
            walking ? (completedSteps + travel) * stepDuration : activeDuration
        )
        let walkingShare = activeDuration / burstDuration
        let pathDuration = profile.pathDuration + seed * 8
        let pathProgress = reduceMotion ? seed : walkingElapsed / (pathDuration * walkingShare) + seed
        let ground = position(progress: pathProgress, seed: seed, size: size)
        let ahead = position(progress: pathProgress + 0.0001, seed: seed, size: size)
        let facing: CGFloat = ahead.x < ground.x ? -1 : 1

        if reduceMotion || !walking {
            return FlameHopPose(groundPosition: ground, frameIndex: 0, lift: 0, lead: 0,
                                 faceRotation: 0, dustOpacity: 0, dustSpread: 0,
                                 shadowScale: 1, facing: facing)
        }

        let frameIndex = min(15, Int(stepPhase * 16))
        let pulse = CGFloat(sin(.pi * stepPhase))
        let lift: CGFloat
        switch kind {
        case .calm: lift = profile.lift * CGFloat(0.5 - 0.5 * cos(2 * .pi * stepPhase))
        case .anxiety: lift = profile.lift * max(0, CGFloat(sin(3 * .pi * stepPhase)))
        case .anger: lift = profile.lift * CGFloat(pow(max(0, sin(.pi * stepPhase)), 0.65))
        default: lift = profile.lift * pulse
        }
        let lead = profile.lead * pulse
        let dustLife = min(1, max(0, (stepPhase - 0.27) / 0.48))
        let dust = stepPhase >= 0.27 && stepPhase < 0.75
            ? profile.dust * (1 - dustLife) : 0
        let body = FlameBodyMotion.sample(kind: kind, phase: stepPhase)
        let faceRotation: Double
        if kind == .joy {
            switch frameIndex {
            case 3...7: faceRotation = -12
            case 8...10: faceRotation = -28
            case 11...12: faceRotation = -18
            default: faceRotation = 0
            }
        } else {
            faceRotation = 0
        }

        return FlameHopPose(
            groundPosition: ground,
            frameIndex: frameIndex,
            lift: lift,
            lead: lead,
            faceRotation: faceRotation,
            dustOpacity: dust,
            dustSpread: CGFloat(dustLife),
            shadowScale: kind == .joy ? 1 - lift / 28 : max(0.78, 1 - lift / 28),
            facing: facing,
            body: body
        )
    }

    static func seed(for id: UUID) -> Double {
        let hash = id.uuidString.utf8.reduce(UInt64(1469598103934665603)) { value, byte in
            (value ^ UInt64(byte)) &* 1099511628211
        }
        return Double(hash % 10_000) / 10_000
    }

    private static func position(progress: Double, seed: Double, size: CGSize) -> CGPoint {
        let angle = 2 * Double.pi * (progress - floor(progress) + seed * 0.5)
        let xWave = 0.86 * sin(angle) + 0.08 * sin(3 * angle + seed * 4)
        let yWave = 0.86 * cos(angle) + 0.08 * sin(2 * angle + seed * 5)
        let xRadius = max(0, (size.width - 96) / 2)
        let yRadius = max(0, (size.height - 112) / 2)
        return CGPoint(x: size.width / 2 + xRadius * CGFloat(xWave),
                       y: size.height / 2 + yRadius * CGFloat(yWave))
    }

    private static func smoothstep(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }
}
