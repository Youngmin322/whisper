import CoreGraphics
import Foundation

struct FlameHopPose {
    let groundPosition: CGPoint
    let lift: CGFloat
    let lead: CGFloat
    let dustOpacity: Double
    let dustSpread: CGFloat
    let shadowScale: CGFloat
    let facing: CGFloat
    var body: FlameBodyPose = .rest
    var isMoving = false
    var facingScale: CGFloat = 1
    var blinkScale: CGFloat = 1
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
    /// Time from the start of a step until the body touches the ground again.
    var flightDuration: TimeInterval { FlameForwardHop.style(for: kind).contactTime(stepDuration: stepDuration) }

    func position(at time: TimeInterval) -> CGPoint {
        let elapsed = min(duration, max(0, time - startedAt))
        let stepClock = elapsed / stepDuration
        let completed = floor(stepClock)
        let stepElapsed = elapsed >= duration ? stepDuration : (stepClock - completed) * stepDuration
        let finished = elapsed >= duration ? Double(steps - 1) : completed
        let travel = FlameForwardHop.style(for: kind).travel(stepElapsed: stepElapsed, stepDuration: stepDuration)
        let progress = CGFloat(min(1, (finished + travel) / Double(steps)))
        return CGPoint(x: from.x + (to.x - from.x) * progress,
                       y: from.y + (to.y - from.y) * progress)
    }
}

enum FlameHopMotion {
    static let landingDuration: TimeInterval = 0.16
    static let turnDuration: TimeInterval = 0.10

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
                groundPosition: ground, lift: 0, lead: 0, dustOpacity: 0, dustSpread: 0, shadowScale: 1,
                facing: restFacing,
                body: reduceMotion ? .rest : idleBody(kind: kind, seed: seed, elapsed: time - restStart),
                facingScale: restFacing,
                blinkScale: reduceMotion ? 1 : idleBlinkScale(seed: seed, elapsed: time - restStart)
            )
        }

        let profile = FlameMotionProfile.forKind(run.kind)
        let style = FlameForwardHop.style(for: run.kind)
        let stepClock = (time - run.startedAt) / run.stepDuration
        let stepElapsed = (stepClock - floor(stepClock)) * run.stepDuration
        // Mirrored artwork flips the pose with it, so only unmirrored artwork needs a signed lean.
        let lean = run.kind.mirrorsArtwork ? 1 : run.facing
        let hop = style.sample(stepElapsed: stepElapsed, stepDuration: run.stepDuration,
                               lean: lean, profile: profile)
        // Dust follows the landing, after the body has descended.
        let dustLife = hop.landingElapsed.map { min(1, $0 / landingDuration) } ?? 0
        let dust = hop.landingElapsed == nil ? 0 : profile.dust * (1 - dustLife)
        var body = hop.body.faded(by: run.strength)
        let lift = hop.lift * run.strength
        let turn = smoothstep((time - run.startedAt) / turnDuration)
        let facingScale = facing + (run.facing - facing) * CGFloat(turn)
        // Carry the last idle pose into takeoff, including a blink caught mid-close.
        let idleElapsed = run.startedAt - restingSince
        if turn < 1 {
            let idle = idleBody(kind: run.kind, seed: seed, elapsed: idleElapsed).faded(by: 1 - CGFloat(turn))
            body.tipBend += idle.tipBend
            body.baseCompression += idle.baseCompression
            body.rotation += idle.rotation
        }
        if run.kind.mirrorsArtwork && turn > 0 && turn < 1 {
            body.rotation += 1.8 * sin(.pi * turn) * Double((run.facing - facing) / 2)
        }

        return FlameHopPose(
            groundPosition: ground, lift: lift, lead: 0,
            dustOpacity: dust * Double(run.strength), dustSpread: CGFloat(dustLife),
            shadowScale: max(0.7, 1 - lift / 28),
            facing: run.facing, body: body, isMoving: true, facingScale: facingScale,
            blinkScale: turn < 1 ? 1 + (idleBlinkScale(seed: seed, elapsed: idleElapsed) - 1) * CGFloat(1 - turn) : 1
        )
    }

    /// `destination` and `others` are field points. A destination only steers the journey: the step count
    /// and tempo stay the character's own, so company never changes when or how long anyone moves.
    /// `eager` is the hurried stride used while answering a touch.
    static func makeRun(
        seed: Double, kind: FlameMotionKind, index: Int, at time: TimeInterval,
        from: CGPoint, size: CGSize,
        toward destination: CGPoint? = nil, eager: Bool = false, avoiding others: [CGPoint] = []
    ) -> FlameHopRun {
        let profile = FlameMotionProfile.forKind(kind)
        var steps = 1 + min(profile.stepsPerBurst - 1,
                            Int(random(seed: seed, index: index, channel: 1) * Double(profile.stepsPerBurst)))
        let personalTempo = 0.95 + random(seed: seed, index: 0, channel: 2) * 0.10
        let tempo = personalTempo * (0.97 + random(seed: seed, index: index, channel: 3) * 0.06)
        var distance = profile.stepDistance * CGFloat(steps)
            * CGFloat(0.85 + random(seed: seed, index: index, channel: 4) * 0.30)
        let bounds = fieldBounds(size)
        let origin = fieldPosition(from, size: size)
        var target = origin
        if let destination {
            if eager {
                steps = max(2, profile.stepsPerBurst)
                distance = profile.stepDistance * 1.6 * CGFloat(steps)
            }
            let gap = hypot(destination.x - origin.x, destination.y - origin.y)
            let share = gap > 0 ? min(distance, gap) / gap : 0
            // Stop short rather than land on someone standing in the way.
            var bestClearance: CGFloat = -1
            for shortening in [1, 0.75, 0.5, 0.25, 0] as [CGFloat] {
                let candidate = CGPoint(
                    x: min(bounds.maxX, max(bounds.minX, origin.x + (destination.x - origin.x) * share * shortening)),
                    y: min(bounds.maxY, max(bounds.minY, origin.y + (destination.y - origin.y) * share * shortening))
                )
                let clearance = others.map { hypot($0.x - candidate.x, $0.y - candidate.y) }.min()
                    ?? .greatestFiniteMagnitude
                if clearance > bestClearance { target = candidate; bestClearance = clearance }
                if clearance >= 40 { break }
            }
        } else {
            // A wander prefers a landing spot that is not on top of someone else.
            var bestClearance: CGFloat = -1
            for attempt in 0..<(others.isEmpty ? 1 : 4) {
                let angle = 2 * Double.pi * random(seed: seed, index: index,
                                                   channel: attempt == 0 ? 5 : 20 + UInt64(attempt))
                let candidate = CGPoint(
                    x: reflect(origin.x + distance * CGFloat(cos(angle)), lower: bounds.minX, upper: bounds.maxX),
                    y: reflect(origin.y + distance * CGFloat(sin(angle)), lower: bounds.minY, upper: bounds.maxY)
                )
                let clearance = others.map { hypot($0.x - candidate.x, $0.y - candidate.y) }.min()
                    ?? .greatestFiniteMagnitude
                if clearance > bestClearance { target = candidate; bestClearance = clearance }
                if clearance >= 44 { break }
            }
        }
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

    /// The inverse of `fieldPosition`, kept inside the walkable area.
    static func normalizedPosition(_ point: CGPoint, size: CGSize) -> CGPoint {
        let bounds = fieldBounds(size)
        return CGPoint(
            x: bounds.width > 0 ? min(1, max(0, (point.x - bounds.minX) / bounds.width)) : 0.5,
            y: bounds.height > 0 ? min(1, max(0, (point.y - bounds.minY) / bounds.height)) : 0.5
        )
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
        case .joy: amplitude = 0.012
        case .calm: amplitude = 0.010
        case .anxiety: amplitude = 0.006
        case .depression: amplitude = 0.003
        case .anger: amplitude = 0.007
        case .sadness: amplitude = 0.004
        }
        let t = max(0, elapsed)
        let fade = CGFloat(smoothstep(t / 0.6))
        let period = 2.5 + 0.5 * random(seed: seed, index: 0, channel: 9)
        let offset = 2 * Double.pi * random(seed: seed, index: 0, channel: 12)
        let breath = 0.005 + 0.025 * sin(2 * .pi * t / period + offset)
        let sway = 0.7 * sin(2 * .pi * t / 4.7 + offset)
            + 0.3 * sin(2 * .pi * t / 2.3 + offset * 1.7)
        let glanceIndex = Int(t / 7)
        let glanceStart = Double(glanceIndex) * 7 + 2
            + 2 * random(seed: seed, index: glanceIndex, channel: 13)
        let glance = pulse((t - glanceStart) / 1.8)
        let direction = random(seed: seed, index: glanceIndex, channel: 14) < 0.5 ? -1.0 : 1.0
        return FlameBodyPose(tipBend: amplitude * fade * CGFloat(sway),
                             baseCompression: CGFloat(breath) * fade,
                             rotation: 1.8 * direction * glance * Double(fade))
    }

    /// Seeded 4–6 second gaps, so redraws and different refresh rates never reroll a blink.
    private static func idleBlinkScale(seed: Double, elapsed: TimeInterval) -> CGFloat {
        guard elapsed >= 0 else { return 1 }
        let index = Int(elapsed / 5)
        var closure = 0.0
        for cycle in max(0, index - 1)...index {
            let start = Double(cycle) * 5 + 4 + random(seed: seed, index: cycle, channel: 15)
            closure = max(closure, pulse((elapsed - start) / 0.15))
        }
        return 1 - 0.92 * CGFloat(closure)
    }

    private static func pulse(_ phase: Double) -> Double {
        guard phase > 0 && phase < 1 else { return 0 }
        return pow(sin(.pi * phase), 2)
    }

}

/// Every emotion hops the same way — crouch, pitched arc, landing that squashes, rocks, and settles —
/// but with its own timing and spring. Solved in closed form so any redraw time gives the same pose.
struct FlameForwardHop {
    var crouchDuration: TimeInterval
    var landingDuration: TimeInterval
    /// Forward lean in degrees while crouching, at the apex, and the swing either side of the apex.
    var crouchPitch: Double
    var apexPitch: Double
    var pitchSwing: Double
    var crouchSquash: CGFloat
    var airStretch: CGFloat
    /// Share of a step's distance covered in the air; the rest is the slide after contact.
    var airTravel: Double = 0.86
    var squashVelocity: Double
    var squashDecay: Double
    var squashPeriod: Double
    var pitchVelocity: Double
    var pitchDecay: Double
    var pitchPeriod: Double
    var tipVelocity: Double
    /// A nervous tremble while gathering, and a sharp shudder on contact.
    var crouchShiver: Double = 0
    var landingShake: Double = 0

    struct Sample {
        var lift: CGFloat
        var body: FlameBodyPose
        var landingElapsed: TimeInterval?
    }

    static func style(for kind: FlameMotionKind) -> Self {
        switch kind {
        case .joy:
            .init(crouchDuration: 0.14, landingDuration: 0.20, crouchPitch: 11, apexPitch: 5, pitchSwing: 13,
                  crouchSquash: -0.18, airStretch: 0.14,
                  squashVelocity: -14, squashDecay: 0.09, squashPeriod: 0.20,
                  pitchVelocity: 480, pitchDecay: 0.09, pitchPeriod: 0.26, tipVelocity: 3.4)
        case .calm:
            .init(crouchDuration: 0.35, landingDuration: 0.45, crouchPitch: 4, apexPitch: 2, pitchSwing: 4,
                  crouchSquash: -0.08, airStretch: 0.05, airTravel: 0.9,
                  squashVelocity: -2.5, squashDecay: 0.14, squashPeriod: 0.45,
                  pitchVelocity: 60, pitchDecay: 0.15, pitchPeriod: 0.5, tipVelocity: 0.6)
        case .anxiety:
            .init(crouchDuration: 0.16, landingDuration: 0.13, crouchPitch: 6, apexPitch: 3, pitchSwing: 6,
                  crouchSquash: -0.12, airStretch: 0.08, airTravel: 0.9,
                  squashVelocity: -9, squashDecay: 0.06, squashPeriod: 0.14,
                  pitchVelocity: 250, pitchDecay: 0.06, pitchPeriod: 0.18, tipVelocity: 2.5,
                  crouchShiver: 2.5)
        case .depression:
            .init(crouchDuration: 0.45, landingDuration: 0.40, crouchPitch: 3, apexPitch: 1, pitchSwing: 2,
                  crouchSquash: -0.10, airStretch: 0.03, airTravel: 0.95,
                  squashVelocity: -4, squashDecay: 0.18, squashPeriod: 0.5,
                  pitchVelocity: 25, pitchDecay: 0.2, pitchPeriod: 0.6, tipVelocity: 0.3)
        case .anger:
            .init(crouchDuration: 0.09, landingDuration: 0.17, crouchPitch: 14, apexPitch: 8, pitchSwing: 14,
                  crouchSquash: -0.20, airStretch: 0.16, airTravel: 0.8,
                  squashVelocity: -16, squashDecay: 0.07, squashPeriod: 0.16,
                  pitchVelocity: 520, pitchDecay: 0.07, pitchPeriod: 0.2, tipVelocity: 4,
                  landingShake: 2.5)
        case .sadness:
            .init(crouchDuration: 0.30, landingDuration: 0.50, crouchPitch: 4, apexPitch: 2, pitchSwing: 3,
                  crouchSquash: -0.08, airStretch: 0.04, airTravel: 0.92,
                  squashVelocity: -4, squashDecay: 0.2, squashPeriod: 0.7,
                  pitchVelocity: 40, pitchDecay: 0.2, pitchPeriod: 0.6, tipVelocity: 0.5)
        }
    }

    /// Short steps keep at least 40% of their time in the air by shortening crouch and landing together.
    private func phases(stepDuration: TimeInterval) -> (crouch: TimeInterval, air: TimeInterval, landing: TimeInterval) {
        let scale = min(1, stepDuration * 0.6 / (crouchDuration + landingDuration))
        let crouch = crouchDuration * scale, landing = landingDuration * scale
        return (crouch, max(0.01, stepDuration - crouch - landing), landing)
    }

    func airDuration(stepDuration: TimeInterval) -> TimeInterval { phases(stepDuration: stepDuration).air }

    func contactTime(stepDuration: TimeInterval) -> TimeInterval {
        let phases = phases(stepDuration: stepDuration)
        return phases.crouch + phases.air
    }

    func travel(stepElapsed: TimeInterval, stepDuration: TimeInterval) -> Double {
        let (crouch, air, landing) = phases(stepDuration: stepDuration)
        let t = stepElapsed - crouch
        guard t > 0 else { return 0 }
        if t < air { return airTravel * t / air }
        let landed = t - air
        guard landed < landing else { return 1 }
        let decay = landing / 4
        let slide = (1 - exp(-landed / decay)) / (1 - exp(-4))
        return airTravel + (1 - airTravel) * slide
    }

    func sample(stepElapsed: TimeInterval, stepDuration: TimeInterval,
                lean: CGFloat, profile: FlameMotionProfile) -> Sample {
        let (crouch, air, landing) = phases(stepDuration: stepDuration)
        let trail = profile.tipBend
        let t = max(0, stepElapsed)

        if t < crouch {
            let c = FlameHopMotion.smoothstep(t / crouch)
            let shiver = crouchShiver * sin(2 * .pi * t / 0.035) * c
            return Sample(lift: 0, body: FlameBodyPose(
                tipBend: -lean * trail * 0.4 * CGFloat(c),
                rotation: Double(lean) * (crouchPitch * c + shiver),
                stretch: crouchSquash * CGFloat(c)))
        }

        if t < crouch + air {
            let u = (t - crouch) / air
            let rise = 1 - 2 * u
            let launch = FlameHopMotion.smoothstep(u / 0.18)
            let stretch = crouchSquash + (airStretch * CGFloat(abs(rise)) - crouchSquash) * CGFloat(launch)
            let pitch = crouchPitch + ((apexPitch + pitchSwing * rise) - crouchPitch) * launch
            let tip = trail * (0.4 + 0.6 * CGFloat(launch))
            return Sample(lift: profile.lift * CGFloat(4 * u * (1 - u)), body: FlameBodyPose(
                tipBend: -lean * tip, rotation: Double(lean) * pitch, stretch: stretch))
        }

        // Underdamped responses start where the arc ended, then fade to rest before the next crouch.
        let landed = min(landing, t - crouch - air)
        let fade = 1 - FlameHopMotion.smoothstep((landed - landing * 0.7) / (landing * 0.3))
        let stretch = Self.settle(start: Double(airStretch), velocity: squashVelocity,
                                  decay: squashDecay, period: squashPeriod, at: landed)
        var pitch = Self.settle(start: apexPitch - pitchSwing, velocity: pitchVelocity,
                                decay: pitchDecay, period: pitchPeriod, at: landed)
        pitch += landingShake * sin(2 * .pi * landed / 0.05) * exp(-landed / 0.06)
        let tip = Self.settle(start: -Double(trail), velocity: tipVelocity,
                              decay: pitchDecay, period: pitchPeriod, at: landed)
        return Sample(lift: 0, body: FlameBodyPose(
            tipBend: lean * CGFloat(tip * fade), rotation: Double(lean) * pitch * fade,
            stretch: CGFloat(stretch * fade)), landingElapsed: landed)
    }

    /// x(0) = start, x'(0) = velocity, decaying oscillation.
    private static func settle(start: Double, velocity: Double, decay: Double,
                               period: Double, at t: Double) -> Double {
        let omega = 2 * Double.pi / period
        let sine = (velocity + start / decay) / omega
        return exp(-t / decay) * (start * cos(omega * t) + sine * sin(omega * t))
    }
}
