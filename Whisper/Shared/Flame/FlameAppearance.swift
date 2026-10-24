import UIKit

/// Artwork selection belongs here; walking and deformation never depend on an emotion.
struct FlameAppearance {
    let assetName: String

    static func resolve(_ emotion: String?) -> Self {
        let assetName: String
        switch emotion ?? "" {
        case WhisperEmotion.calm.rawValue, "차분함": assetName = "EmotionFlameCalm"
        case WhisperEmotion.tired.rawValue, WhisperEmotion.depression.rawValue: assetName = "EmotionFlameDepression"
        case WhisperEmotion.anxiety.rawValue: assetName = "EmotionFlameAnxiety"
        case WhisperEmotion.anger.rawValue: assetName = "EmotionFlameAnger"
        case WhisperEmotion.sadness.rawValue, "속상": assetName = "EmotionFlameSadness"
        default: assetName = "EmotionFlameJoy"
        }
        return Self(assetName: assetName)
    }

    /// Locate the visible artwork in the same aspect-fit canvas used by FlameCharacter.
    /// Reading alpha once also accommodates replacement PNGs with different transparent margins.
    @MainActor
    func rigBounds(characterSize: CGFloat, canvasSize: CGFloat) -> CGRect {
        let geometry = Self.geometry(for: assetName)
        let frame = CGSize(width: characterSize, height: characterSize * 1.1)
        let scale = min(frame.width / geometry.imageSize.width, frame.height / geometry.imageSize.height)
        let fitted = CGSize(width: geometry.imageSize.width * scale, height: geometry.imageSize.height * scale)
        let origin = CGPoint(x: (canvasSize - fitted.width) / 2, y: (canvasSize - fitted.height) / 2)
        return CGRect(
            x: origin.x + geometry.visibleBounds.minX * fitted.width,
            y: origin.y + geometry.visibleBounds.minY * fitted.height,
            width: geometry.visibleBounds.width * fitted.width,
            height: geometry.visibleBounds.height * fitted.height
        )
    }

    private struct ArtworkGeometry {
        let imageSize: CGSize
        let visibleBounds: CGRect
    }

    @MainActor private static var geometryCache: [String: ArtworkGeometry] = [:]

    @MainActor
    private static func geometry(for asset: String) -> ArtworkGeometry {
        if let cached = geometryCache[asset] { return cached }
        guard let image = UIImage(named: asset), let cgImage = image.cgImage else {
            return ArtworkGeometry(imageSize: CGSize(width: 1, height: 1), visibleBounds: CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        // Only bounds are needed: keep this scan small even for high-resolution artwork.
        let scanScale = min(1, 160 / CGFloat(max(cgImage.width, cgImage.height)))
        let width = max(1, Int(CGFloat(cgImage.width) * scanScale))
        let height = max(1, Int(CGFloat(cgImage.height) * scanScale))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let bounds = pixels.withUnsafeMutableBytes { bytes -> CGRect in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            let rgba = bytes.bindMemory(to: UInt8.self)
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where rgba[(y * width + x) * 4 + 3] > 8 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
            return CGRect(
                x: CGFloat(minX) / CGFloat(width), y: CGFloat(minY) / CGFloat(height),
                width: CGFloat(maxX - minX + 1) / CGFloat(width),
                height: CGFloat(maxY - minY + 1) / CGFloat(height)
            )
        }
        let geometry = ArtworkGeometry(imageSize: image.size, visibleBounds: bounds)
        geometryCache[asset] = geometry
        return geometry
    }
}
