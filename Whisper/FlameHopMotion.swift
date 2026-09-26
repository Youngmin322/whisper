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
    static func sample(
        seed: Double,
        time: TimeInterval,
        size: CGSize,
        reduceMotion: Bool
    ) -> FlameHopPose {
        let stepDuration = 0.19 + seed * 0.03
        let stepsPerBurst = 3 + Int(seed * 3)
        let activeDuration = stepDuration * Double(stepsPerBurst)
        let pauseDuration = 0.52 + seed * 0.25
        let burstDuration = activeDuration + pauseDuration
        let clock = time + seed * burstDuration
        let burstIndex = floor(clock / burstDuration)
        let withinBurst = clock - burstIndex * burstDuration
        let walking = withinBurst < activeDuration
        let walkingElapsed = burstIndex * activeDuration + min(withinBurst, activeDuration)
        let walkingShare = activeDuration / burstDuration
        let pathDuration = 88 + seed * 10
        let pathProgress = reduceMotion
            ? seed
            : walkingElapsed / (pathDuration * walkingShare) + seed
        let ground = position(progress: pathProgress, seed: seed, size: size)
        let ahead = position(progress: pathProgress + 0.0001, seed: seed, size: size)
        let dx = ahead.x - ground.x
        let dy = ahead.y - ground.y
        let distance = max(0.0001, sqrt(dx * dx + dy * dy))
        let directionX = dx / distance
        let directionY = dy / distance
        let facing: CGFloat = dx < 0 ? -1 : 1

        if reduceMotion {
            return FlameHopPose(
                groundPosition: ground,
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

        let stepClock = withinBurst / stepDuration
        let stepPhase = stepClock - floor(stepClock)
        let stride = walking ? sin(.pi * stepPhase) : 0
        let lift = 1.8 * stride
        let dustLife = min(1, stepPhase / 0.26)

        return FlameHopPose(
            groundPosition: ground,
            lift: CGFloat(lift),
            bodyOffsetY: 0,
            bodyScaleX: CGFloat(1 - 0.015 * stride),
            bodyScaleY: CGFloat(1 + 0.02 * stride),
            bodyLean: -5 * Double(directionX) * stride,
            faceOffsetX: -directionX * CGFloat(2 * stride),
            faceOffsetY: -directionY * CGFloat(1.8 * stride),
            faceYaw: Double(directionX) * 14,
            dustOpacity: walking && stepPhase < 0.26 ? 0.18 * (1 - dustLife) : 0,
            dustSpread: CGFloat(dustLife),
            shadowScale: CGFloat(1 - lift / 25),
            facing: facing
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
        return CGPoint(
            x: size.width / 2 + xRadius * CGFloat(xWave),
            y: size.height / 2 + yRadius * CGFloat(yWave)
        )
    }

}
