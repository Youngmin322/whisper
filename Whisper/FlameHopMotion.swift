import CoreGraphics
import Foundation

struct FlameHopPose {
    let groundPosition: CGPoint
    let lift: CGFloat
    let bodyOffsetY: CGFloat
    let bodyScaleX: CGFloat
    let bodyScaleY: CGFloat
    let bodyLean: Double
    let faceOffsetX: CGFloat
    let faceOffsetY: CGFloat
    let faceYaw: Double
    let dustOpacity: Double
    let dustSpread: CGFloat
    let shadowScale: CGFloat
    let facing: CGFloat
}

enum FlameHopMotion {
    static let waypointCount = 32

    static func sample(
        seed: Double,
        time: TimeInterval,
        size: CGSize,
        reduceMotion: Bool
    ) -> FlameHopPose {
        let cycle = 2.7 + seed * 0.6
        let timeline = time / cycle + seed * 31
        let step = reduceMotion ? floor(seed * Double(waypointCount)) : floor(timeline)
        let index = Int(step.truncatingRemainder(dividingBy: Double(waypointCount)))
        let phase = timeline - step
        let from = waypoint(index: index, seed: seed, size: size)
        let to = waypoint(index: (index + 1) % waypointCount, seed: seed, size: size)
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = max(1, sqrt(dx * dx + dy * dy))
        let directionX = dx / distance
        let directionY = dy / distance
        let facing: CGFloat = dx < 0 ? -1 : 1

        if reduceMotion {
            return FlameHopPose(
                groundPosition: from,
                lift: 0,
                bodyOffsetY: 0,
                bodyScaleX: 1,
                bodyScaleY: 1,
                bodyLean: 0,
                faceOffsetX: 0,
                faceOffsetY: 0,
                faceYaw: 0,
                dustOpacity: 0,
                dustSpread: 0,
                shadowScale: 1,
                facing: facing
            )
        }

        let crouchEnd = 0.14
        let apex = 0.36
        let landingStart = 0.53
        let recoveryEnd = 0.69
        let travel: Double
        let lift: Double
        let bodyScaleX: Double
        let bodyScaleY: Double
        let bodyOffsetY: Double
        let lean: Double

        if phase < crouchEnd {
            let compression = smoothstep(phase / crouchEnd)
            travel = 0
            lift = 0
            bodyScaleX = 1 + 0.11 * compression
            bodyScaleY = 1 - 0.18 * compression
            bodyOffsetY = 3 * compression
            lean = -3 * Double(directionX) * compression
        } else if phase < landingStart {
            let arc: Double
            if phase < apex {
                let rising = (phase - crouchEnd) / (apex - crouchEnd)
                arc = sin(.pi / 2 * rising)
            } else {
                let falling = (phase - apex) / (landingStart - apex)
                arc = cos(.pi / 2 * falling)
            }
            travel = smoothstep((phase - crouchEnd) / (landingStart - crouchEnd))
            lift = 25 * arc
            bodyScaleX = 1 - 0.06 * arc
            bodyScaleY = 1 + 0.13 * arc
            bodyOffsetY = 0
            lean = 9 * Double(directionX) * arc
        } else if phase < recoveryEnd {
            let recovery = smoothstep((phase - landingStart) / (recoveryEnd - landingStart))
            travel = 1
            lift = 0
            bodyScaleX = 1 + 0.13 * (1 - recovery)
            bodyScaleY = 1 - 0.20 * (1 - recovery)
            bodyOffsetY = 3.5 * (1 - recovery)
            lean = -4 * Double(directionX) * (1 - recovery)
        } else {
            travel = 1
            lift = 0
            bodyScaleX = 1
            bodyScaleY = 1 + 0.012 * sin(.pi * (phase - recoveryEnd) / (1 - recoveryEnd))
            bodyOffsetY = 0
            lean = 1.3 * Double(directionX) * sin(.pi * (phase - recoveryEnd) / (1 - recoveryEnd))
        }

        let ground = CGPoint(
            x: from.x + dx * CGFloat(travel),
            y: from.y + dy * CGFloat(travel)
        )
        let dustLife = max(0, min(1, (phase - landingStart) / 0.20))
        let dustOpacity = phase >= landingStart && phase < landingStart + 0.20
            ? 0.55 * (1 - dustLife)
            : 0

        return FlameHopPose(
            groundPosition: ground,
            lift: CGFloat(lift),
            bodyOffsetY: CGFloat(bodyOffsetY),
            bodyScaleX: CGFloat(bodyScaleX),
            bodyScaleY: CGFloat(bodyScaleY),
            bodyLean: lean,
            faceOffsetX: directionX * 3.6,
            faceOffsetY: directionY * 1.8,
            faceYaw: Double(directionX) * 18,
            dustOpacity: dustOpacity,
            dustSpread: CGFloat(dustLife),
            shadowScale: CGFloat(1 - lift / 90),
            facing: facing
        )
    }

    static func seed(for id: UUID) -> Double {
        let hash = id.uuidString.utf8.reduce(UInt64(1469598103934665603)) { value, byte in
            (value ^ UInt64(byte)) &* 1099511628211
        }
        return Double(hash % 10_000) / 10_000
    }

    private static func waypoint(index: Int, seed: Double, size: CGSize) -> CGPoint {
        let angle = 2 * Double.pi * (Double(index) / Double(waypointCount) + seed * 0.5)
        let xWave = 0.86 * sin(angle) + 0.08 * sin(3 * angle + seed * 4)
        let yWave = 0.86 * cos(angle) + 0.08 * sin(2 * angle + seed * 5)
        let xRadius = max(0, (size.width - 96) / 2)
        let yRadius = max(0, (size.height - 112) / 2)
        return CGPoint(
            x: size.width / 2 + xRadius * CGFloat(xWave),
            y: size.height / 2 + yRadius * CGFloat(yWave)
        )
    }

    private static func smoothstep(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * (3 - 2 * x)
    }
}
