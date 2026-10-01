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
    var isMoving = false
    var referenceBlend: CGFloat = 0
}

/// One short journey. Normalized positions preserve a character's place across layout changes.
struct FlameHopRun {
    let kind: FlameMotionKind
    var startedAt: TimeInterval
    let from: CGPoint
    let to: CGPoint
    let stepDuration: TimeInterval
    let steps: Int
    var strength: CGFloat = 1

    var duration: TimeInterval { stepDuration * Double(steps) }
    var endsAt: TimeInterval { startedAt + duration }
    var facing: CGFloat { to.x < from.x ? -1 : 1 }

    func position(at time: TimeInterval) -> CGPoint {
        let elapsed = min(duration, max(0, time - startedAt))
        let stepClock = elapsed / stepDuration
        let completed = floor(stepClock)
        let phase = stepClock - completed
        let travel: Double
        switch kind {
        case .anger: travel = pow(phase, 0.55)
        case .anxiety: travel = FlameHopMotion.smoothstep((phase - 0.18) / 0.82)
        case .sadness: travel = FlameHopMotion.smoothstep((phase - 0.10) / 0.90)
        default: travel = FlameHopMotion.smoothstep(phase)
        }
        let progress = CGFloat(min(1, (completed + travel) / Double(steps)))
        return CGPoint(x: from.x + (to.x - from.x) * progress,
                       y: from.y + (to.y - from.y) * progress)
    }
}

enum FlameHopMotion {
    static func sample(
        run: FlameHopRun?, time: TimeInterval, size: CGSize,
        restingAt anchor: CGPoint, restingSince: TimeInterval,
        facing: CGFloat, seed: Double, kind: FlameMotionKind, reduceMotion: Bool
    ) -> FlameHopPose {
        let position = run?.position(at: time) ?? anchor
        let ground = fieldPosition(position, size: size)
        guard !reduceMotion, let run, time >= run.startedAt, time < run.endsAt else {
            let restStart = run.map { max(restingSince, $0.endsAt) } ?? restingSince
            let restFacing = run.flatMap { time >= $0.startedAt ? $0.facing : nil } ?? facing
            return FlameHopPose(
                groundPosition: ground, frameIndex: 0, lift: 0, lead: 0,
                faceRotation: 0, dustOpacity: 0, dustSpread: 0, shadowScale: 1,
                facing: restFacing,
                body: reduceMotion ? .rest : idleBody(kind: kind, seed: seed, elapsed: time - restStart)
            )
        }

        let profile = FlameMotionProfile.forKind(run.kind)
        let stepClock = (time - run.startedAt) / run.stepDuration
        let phase = stepClock - floor(stepClock)
        let frameIndex = min(15, Int(phase * 16))
        let pulse = CGFloat(sin(.pi * phase))
        let lift: CGFloat
        switch run.kind {
        case .calm: lift = profile.lift * CGFloat(0.5 - 0.5 * cos(2 * .pi * phase))
        case .anxiety: lift = profile.lift * max(0, CGFloat(sin(3 * .pi * phase)))
        case .anger: lift = profile.lift * CGFloat(pow(max(0, sin(.pi * phase)), 0.65))
        default: lift = profile.lift * pulse
        }
        // Dust follows the landing, after the body has descended.
        let dustLife = min(1, max(0, (phase - 0.78) / 0.22))
        let dust = phase >= 0.78 ? profile.dust * (1 - dustLife) : 0
        var body = FlameBodyMotion.sample(kind: run.kind, phase: phase)
        body.tipBend *= run.strength
        body.footPush *= run.strength
        body.baseCompression *= run.strength
        body.rotation *= Double(run.strength)
        let faceRotation: Double
        if run.kind == .joy {
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
            groundPosition: ground, frameIndex: frameIndex,
            lift: lift * run.strength, lead: profile.lead * pulse * run.strength,
            faceRotation: faceRotation, dustOpacity: dust * Double(run.strength),
            dustSpread: CGFloat(dustLife), shadowScale: max(0.78, 1 - lift * run.strength / 28),
            facing: run.facing, body: body, isMoving: true,
            referenceBlend: run.kind == .joy ? joyReferenceBlend(phase: phase) : 0
        )
    }

    /// The last reference frames still lean to one side. Return to the approved
    /// silhouette before landing, instead of snapping to it when the run ends.
    private static func joyReferenceBlend(phase: Double) -> CGFloat {
        let entering = smoothstep((phase - 2.0 / 16.0) / (2.0 / 16.0))
        let settling = 1 - smoothstep((phase - 13.0 / 16.0) / (3.0 / 16.0))
        return CGFloat(entering * settling)
    }

    static func makeRun(
        seed: Double, kind: FlameMotionKind, index: Int, at time: TimeInterval,
        from: CGPoint, size: CGSize
    ) -> FlameHopRun {
        let profile = FlameMotionProfile.forKind(kind)
        let steps = 1 + min(profile.stepsPerBurst - 1,
                            Int(random(seed: seed, index: index, channel: 1) * Double(profile.stepsPerBurst)))
        let personalTempo = 0.95 + random(seed: seed, index: 0, channel: 2) * 0.10
        let tempo = personalTempo * (0.97 + random(seed: seed, index: index, channel: 3) * 0.06)
        let distance = profile.stepDistance * CGFloat(steps)
            * CGFloat(0.85 + random(seed: seed, index: index, channel: 4) * 0.30)
        let angle = 2 * Double.pi * random(seed: seed, index: index, channel: 5)
        let bounds = fieldBounds(size)
        let origin = fieldPosition(from, size: size)
        let target = CGPoint(
            x: reflect(origin.x + distance * CGFloat(cos(angle)), lower: bounds.minX, upper: bounds.maxX),
            y: reflect(origin.y + distance * CGFloat(sin(angle)), lower: bounds.minY, upper: bounds.maxY)
        )
        let to = CGPoint(x: bounds.width > 0 ? (target.x - bounds.minX) / bounds.width : from.x,
                         y: bounds.height > 0 ? (target.y - bounds.minY) / bounds.height : from.y)
        return FlameHopRun(kind: kind, startedAt: time, from: from, to: to,
                           stepDuration: profile.stepDuration * tempo, steps: steps,
                           strength: kind == .joy ? 1 : CGFloat(0.88 + random(seed: seed, index: 0, channel: 6) * 0.12))
    }

    static func seed(for id: UUID) -> Double {
        let hash = id.uuidString.utf8.reduce(UInt64(1469598103934665603)) { value, byte in
            (value ^ UInt64(byte)) &* 1099511628211
        }
        return Double(hash >> 11) / 9_007_199_254_740_992
    }

    /// Stable randomness: a redraw never picks a new path, tempo, or waiting time.
    static func random(seed: Double, index: Int, channel: UInt64) -> Double {
        var value = seed.bitPattern &+ UInt64(truncatingIfNeeded: index) &* 0x9E3779B97F4A7C15
        value &+= channel &* 0xD1B54A32D192ED03
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value >> 11) / 9_007_199_254_740_992
    }

    static func initialPosition(seed: Double) -> CGPoint {
        CGPoint(x: 0.08 + 0.84 * random(seed: seed, index: 0, channel: 7),
                y: 0.08 + 0.84 * random(seed: seed, index: 0, channel: 8))
    }

    static func fieldPosition(_ position: CGPoint, size: CGSize) -> CGPoint {
        let bounds = fieldBounds(size)
        return CGPoint(x: bounds.minX + position.x * bounds.width,
                       y: bounds.minY + position.y * bounds.height)
    }

    static func smoothstep(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }

    private static func fieldBounds(_ size: CGSize) -> CGRect {
        CGRect(x: min(48, size.width / 2), y: min(56, size.height / 2),
               width: max(0, size.width - 96), height: max(0, size.height - 112))
    }

    private static func reflect(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        let span = upper - lower
        guard span > 0 else { return lower }
        let period = span * 2
        let offset = ((value - lower).truncatingRemainder(dividingBy: period) + period)
            .truncatingRemainder(dividingBy: period)
        return lower + (offset <= span ? offset : period - offset)
    }

    private static func idleBody(kind: FlameMotionKind, seed: Double, elapsed: TimeInterval) -> FlameBodyPose {
        let amplitude: CGFloat
        switch kind {
        case .joy: return .rest
        case .calm: amplitude = 0.010
        case .anxiety: amplitude = 0.006
        case .depression: amplitude = 0.003
        case .anger: amplitude = 0.007
        case .sadness: amplitude = 0.004
        }
        let period = 4.8 + 1.6 * random(seed: seed, index: 0, channel: 9)
        let fade = CGFloat(min(1, max(0, elapsed / 0.6)))
        return FlameBodyPose(tipBend: amplitude * fade * CGFloat(sin(2 * .pi * max(0, elapsed) / period)))
    }
}
