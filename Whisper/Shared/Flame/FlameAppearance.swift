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

    /// Eyeball ellipses measured in the approved PNGs, padded to include their anti-aliased rims.
    /// Anxiety's brows overlap its eyes, so a guard line along each brow's lower edge keeps them intact.
    /// Calm's eyes are already closed, so it never blinks.
    @MainActor
    func blinkEyes(characterSize: CGFloat, canvasSize: CGFloat) -> [FlameBlinkEye] {
        let eyes: [(eye: CGRect, padding: CGFloat, guard: (CGPoint, CGPoint)?)]
        switch assetName {
        case "EmotionFlameCalm":
            eyes = []
        case "EmotionFlameAnxiety":
            eyes = [(CGRect(x: 0.383, y: 0.690, width: 0.052, height: 0.052), 1.12,
                     (CGPoint(x: 0.3830, y: 0.7073), CGPoint(x: 0.4167, y: 0.6833))),
                    (CGRect(x: 0.566, y: 0.656, width: 0.050, height: 0.050), 1.12,
                     (CGPoint(x: 0.5567, y: 0.6517), CGPoint(x: 0.6160, y: 0.6585)))]
        case "EmotionFlameDepression":
            // The lidded half-discs have square top corners, which a wider ellipse must cover.
            eyes = [(CGRect(x: 0.381, y: 0.651, width: 0.071, height: 0.047), 1.45, nil),
                    (CGRect(x: 0.549, y: 0.651, width: 0.071, height: 0.046), 1.45, nil)]
        case "EmotionFlameAnger":
            eyes = [(CGRect(x: 0.384, y: 0.670, width: 0.050, height: 0.049), 1.12, nil),
                    (CGRect(x: 0.564, y: 0.670, width: 0.050, height: 0.049), 1.12, nil)]
        case "EmotionFlameSadness":
            eyes = [(CGRect(x: 0.384, y: 0.662, width: 0.051, height: 0.047), 1.12, nil),
                    (CGRect(x: 0.560, y: 0.662, width: 0.050, height: 0.047), 1.12, nil)]
        default:
            // Joy's small source PNG has soft, upscaled eye edges, so its ellipse needs more room.
            eyes = [(CGRect(x: 0.312, y: 0.602, width: 0.086, height: 0.067), 1.35, nil),
                    (CGRect(x: 0.581, y: 0.579, width: 0.086, height: 0.063), 1.35, nil)]
        }
        let imageSize = Self.geometry(for: assetName).imageSize
        let scale = min(characterSize / imageSize.width, characterSize * 1.1 / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (canvasSize - fitted.width) / 2, y: (canvasSize - fitted.height) / 2)
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: origin.x + point.x * fitted.width, y: origin.y + point.y * fitted.height)
        }
        return eyes.map { eye, padding, guardLine in
            let padded = eye.insetBy(dx: -eye.width * (padding - 1) / 2, dy: -eye.height * (padding - 1) / 2)
            let corner = place(padded.origin)
            return FlameBlinkEye(
                ellipse: CGRect(x: corner.x, y: corner.y,
                                width: padded.width * fitted.width, height: padded.height * fitted.height),
                browGuardStart: guardLine.map { place($0.0) },
                browGuardEnd: guardLine.map { place($0.1) }
            )
        }
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

/// One eye's blink area in canvas points. A brow guard keeps everything above its line untouched.
struct FlameBlinkEye: Equatable {
    let ellipse: CGRect
    let browGuardStart: CGPoint?
    let browGuardEnd: CGPoint?
}
