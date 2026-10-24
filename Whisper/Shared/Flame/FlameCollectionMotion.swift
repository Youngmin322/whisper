import CoreGraphics
import Foundation

/// A shared clock keeps the cork, incoming flames and editor transition in order.
struct FlameCollectionMotion {
    let count: Int

    static let flightStart: TimeInterval = 0.48
    static let flightDuration: TimeInterval = 0.78
    static let mouthProgress: CGFloat = 0.72

    private var staggerDuration: TimeInterval { min(0.44, Double(max(0, count - 1)) * 0.065) }
    var closingStartsAt: TimeInterval { Self.flightStart + staggerDuration + Self.flightDuration + 0.08 }
    var duration: TimeInterval { closingStartsAt + 0.30 + 0.24 }

    func appearance(at elapsed: TimeInterval) -> CGFloat {
        smooth(elapsed / 0.20)
    }

    func corkOpenness(at elapsed: TimeInterval) -> CGFloat {
        smooth((elapsed - 0.12) / 0.34) * (1 - smooth((elapsed - closingStartsAt) / 0.30))
    }

    func corkSettle(at elapsed: TimeInterval) -> CGFloat {
        let progress = clamp((elapsed - closingStartsAt - 0.30) / 0.24)
        return CGFloat(sin(progress * .pi)) * 2
    }

    func flightProgress(at elapsed: TimeInterval, index: Int) -> CGFloat {
        let delay = count > 1 ? staggerDuration * Double(index) / Double(count - 1) : 0
        return CGFloat(clamp((elapsed - Self.flightStart - delay) / Self.flightDuration))
    }

    func flight(at elapsed: TimeInterval, index: Int, from origin: CGPoint,
                jar: FlameCollectionJarLayout) -> FlameCollectionPose {
        let progress = flightProgress(at: elapsed, index: index)
        let approach = min(1, progress / Self.mouthProgress)
        let entry = smooth(Double((progress - Self.mouthProgress) / (1 - Self.mouthProgress)))
        let mouth = jar.mouth
        let destination = jar.restingPoint(index: index)
        let point: CGPoint

        if progress <= Self.mouthProgress {
            // Approach from above, including flames that started below the neck.
            let side: CGFloat = origin.x < mouth.x ? -1 : 1
            let clearance = min(origin.y - 48, mouth.y - jar.width * 0.60)
            let control1 = CGPoint(x: origin.x, y: clearance)
            let control2 = CGPoint(x: mouth.x + side * jar.width * 0.30, y: mouth.y - jar.width * 0.70)
            point = cubic(origin, control1, control2, mouth, CGFloat(pow(Double(approach), 1.65)))
        } else {
            point = CGPoint(x: mouth.x + (destination.x - mouth.x) * entry,
                            y: mouth.y + (destination.y - mouth.y) * entry)
        }

        let narrowing = smooth(Double(approach))
        return FlameCollectionPose(
            position: point,
            scaleX: 1 - narrowing * 0.76 + entry * 0.12,
            scaleY: 1 - narrowing * 0.62 - entry * 0.02,
            rotation: Double((origin.x < mouth.x ? 1 : -1) * sin(approach * .pi) * 14),
            opacity: index < 3 ? 1 : Double(1 - entry),
            release: narrowing
        )
    }

    private func clamp(_ value: Double) -> Double { min(1, max(0, value)) }

    private func smooth(_ value: Double) -> CGFloat {
        let t = clamp(value)
        return CGFloat(t * t * (3 - 2 * t))
    }

    private func cubic(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * u * a.x + 3 * u * u * t * b.x + 3 * u * t * t * c.x + t * t * t * d.x,
                       y: u * u * u * a.y + 3 * u * u * t * b.y + 3 * u * t * t * c.y + t * t * t * d.y)
    }
}

struct FlameCollectionPose {
    let position: CGPoint
    let scaleX: CGFloat
    let scaleY: CGFloat
    let rotation: Double
    let opacity: Double
    let release: CGFloat
}

struct FlameCollectionJarLayout {
    let size: CGSize

    var width: CGFloat { min(112, size.width * 0.30, size.height * 0.48) }
    var height: CGFloat { width * WhisperJarDesign.heightToWidth }
    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height - height / 2 - 18) }
    var mouth: CGPoint {
        CGPoint(x: center.x,
                y: center.y - height / 2 + width * WhisperJarDesign.mouth.y / WhisperJarDesign.size.width)
    }
    var mouthWidth: CGFloat { width * WhisperJarDesign.mouthWidth / WhisperJarDesign.size.width }

    func restingPoint(index: Int) -> CGPoint {
        let offsets: [CGPoint] = [CGPoint(x: -0.10, y: 0.22), CGPoint(x: 0.12, y: 0.12), CGPoint(x: 0, y: 0.39)]
        let offset = offsets[index % offsets.count]
        return CGPoint(x: center.x + offset.x * width, y: center.y + offset.y * width)
    }
}
