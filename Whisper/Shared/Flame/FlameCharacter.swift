import SwiftUI

struct FlameCharacter: View {
    let emotion: String?
    var size: CGFloat = 52

    static func assetName(for emotion: String?) -> String {
        FlameAppearance.resolve(emotion).assetName
    }

    var body: some View {
        Image(Self.assetName(for: emotion))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size * 1.1)
            .accessibilityHidden(true)
    }
}

struct AnimatedFlameCharacter: View {
    let emotion: String?
    let pose: FlameHopPose
    var size: CGFloat = 48
    var shadowOpacity: Double = 1

    private var canvasSize: CGFloat { size * 5 / 3 }
    private var motionKind: FlameMotionKind { FlameMotionKind.resolve(emotion) }

    var body: some View {
        let appearance = FlameAppearance.resolve(emotion)
        let bounds = appearance.rigBounds(characterSize: size, canvasSize: canvasSize)
        let eyes = appearance.blinkEyes(characterSize: size, canvasSize: canvasSize)
        ZStack {
            Ellipse()
                .fill(Color.whisperTextSecondary.opacity(0.10))
                .frame(width: size * 0.48 * pose.shadowScale, height: 5)
                .offset(y: size * 0.50)
                .opacity(shadowOpacity)

            FlameCharacter(emotion: emotion, size: size)
                .frame(width: canvasSize, height: canvasSize)
                .layerEffect(
                    ShaderLibrary.flameBlink(
                        ellipseArgument(eyes.first), guardArgument(eyes.first),
                        ellipseArgument(eyes.last), guardArgument(eyes.last),
                        .float(Float(pose.blinkScale))
                    ),
                    maxSampleOffset: .zero,
                    isEnabled: pose.blinkScale < 1 && eyes.count == 2
                )
                .distortionEffect(
                    ShaderLibrary.flameBodyWarp(
                        .float4(Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height)),
                        .float3(Float(pose.body.tipBend), Float(pose.body.footPush), Float(pose.body.baseCompression))
                    ),
                    maxSampleOffset: CGSize(width: size * 0.28, height: size * 0.12),
                    isEnabled: pose.body.tipBend != 0 || pose.body.footPush != 0 || pose.body.baseCompression != 0
                )
                .scaleEffect(x: 1 / sqrt(1 + pose.body.stretch), y: 1 + pose.body.stretch,
                             anchor: UnitPoint(x: bounds.midX / canvasSize, y: bounds.maxY / canvasSize))
                .rotationEffect(.degrees(pose.body.rotation),
                                anchor: UnitPoint(x: bounds.midX / canvasSize, y: bounds.maxY / canvasSize))
                .scaleEffect(pose.body.uniformScale,
                             anchor: UnitPoint(x: bounds.midX / canvasSize, y: bounds.maxY / canvasSize))
                // Joy mirrors its motion, not the approved asymmetric artwork.
                .scaleEffect(x: motionKind.mirrorsArtwork ? pose.facingScale : 0.94 + 0.06 * abs(pose.facingScale), y: 1)
                .offset(x: pose.facing * pose.lead, y: -pose.lift - 1.5)
        }
        .frame(width: canvasSize, height: canvasSize)
        .accessibilityHidden(true)
    }

    private func ellipseArgument(_ eye: FlameBlinkEye?) -> Shader.Argument {
        let rect = eye?.ellipse ?? .zero
        return .float4(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height))
    }

    /// A zero-length guard disables the brow test in the shader.
    private func guardArgument(_ eye: FlameBlinkEye?) -> Shader.Argument {
        guard let start = eye?.browGuardStart, let end = eye?.browGuardEnd else { return .float4(0, 0, 0, 0) }
        return .float4(Float(start.x), Float(start.y), Float(end.x), Float(end.y))
    }
}

struct FlameBottle: View {
    let emotion: String?
    var width: CGFloat = 82

    var body: some View {
        let jar = OriginalWhisperJar(width: width)
        ZStack {
            jar.back
            FlameCharacter(emotion: emotion, size: width * 0.40)
                .offset(y: width * 0.13)
            jar.front
        }
        .frame(width: width, height: width * WhisperJarDesign.heightToWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(WhisperEmotion.displayName(for: emotion) ?? WhisperEmotion.joy.displayName) 불꽃이 담긴 유리병", bundle: WhisperLocalization.bundle, locale: WhisperLocalization.locale))
    }
}
