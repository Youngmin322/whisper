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
        let pathDuration = 88 + seed * 10
        let pathProgress = reduceMotion ? seed : time / pathDuration + seed
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

        let cycle = 0.62 + seed * 0.12
        let timeline = time / cycle + seed * 13
        let phase = timeline - floor(timeline)
        let apex = 0.62
        let arc: Double
        if phase < apex {
            arc = sin(.pi / 2 * phase / apex)
        } else {
            arc = cos(.pi / 2 * (phase - apex) / (1 - apex))
        }
        let impact = phase < 0.10 ? 1 - smoothstep(phase / 0.10) : 0
        let dustLife = min(1, phase / 0.16)
        let lift: Double
        lift = 11 * arc

        return FlameHopPose(
            groundPosition: ground,
            lift: CGFloat(lift),
            bodyOffsetY: CGFloat(1.5 * impact),
            bodyScaleX: CGFloat(1 + 0.055 * impact - 0.025 * arc),
            bodyScaleY: CGFloat(1 - 0.09 * impact + 0.055 * arc),
            bodyLean: 3.5 * Double(directionX) * arc,
            faceOffsetX: directionX * 3.6,
            faceOffsetY: directionY * 1.8,
            faceYaw: Double(directionX) * 18,
            dustOpacity: phase < 0.16 ? 0.35 * (1 - dustLife) : 0,
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

    private static func position(progress: Double, seed: Double, size: CGSize) -> CGPoint {
        let angle = 2 * Double.pi * (progress + seed * 0.5)
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
