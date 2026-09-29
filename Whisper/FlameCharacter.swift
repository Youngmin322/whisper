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

    private var canvasSize: CGFloat { size * 5 / 3 }
    private var motionKind: FlameMotionKind { FlameMotionKind.resolve(emotion) }

    var body: some View {
        let bounds = FlameAppearance.resolve(emotion).rigBounds(characterSize: size, canvasSize: canvasSize)
        ZStack {
            Ellipse()
                .fill(Color.whisperTextSecondary.opacity(0.10))
                .frame(width: size * 0.48 * pose.shadowScale, height: 5)
                .offset(y: size * 0.50)

            animatedArtwork(bounds: bounds)
                .scaleEffect(x: pose.facing, y: 1)
                .offset(x: pose.facing * pose.lead, y: -pose.lift - 1.5)
        }
        .frame(width: canvasSize, height: canvasSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func animatedArtwork(bounds: CGRect) -> some View {
        if motionKind == .joy {
            let reference = FlameReferenceRig.frames[pose.frameIndex]
            ZStack {
                Image("EmotionFlameJoyBody")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size * 1.1)
                    .frame(width: canvasSize, height: canvasSize)
                    .distortionEffect(
                        ShaderLibrary.flameReferenceWarp(
                            .float4(Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height)),
                            .floatArray(reference.mapping)
                        ),
                        maxSampleOffset: CGSize(width: size * 0.8, height: size * 0.8),
                        isEnabled: pose.frameIndex != 0
                    )

                Image("EmotionFlameJoyFace")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size * 1.1)
                    .scaleEffect(reference.faceScale, anchor: UnitPoint(x: 0.5, y: 0.68))
                    .rotationEffect(.degrees(reference.faceRotation), anchor: UnitPoint(x: 0.5, y: 0.68))
                    .frame(width: canvasSize, height: canvasSize)
            }
        } else {
            FlameCharacter(emotion: emotion, size: size)
                .frame(width: canvasSize, height: canvasSize)
                .distortionEffect(
                    ShaderLibrary.flameBodyWarp(
                        .float4(Float(bounds.minX), Float(bounds.minY), Float(bounds.width), Float(bounds.height)),
                        .float3(Float(pose.body.tipBend), Float(pose.body.footPush), Float(pose.body.baseCompression))
                    ),
                    maxSampleOffset: CGSize(width: size * 0.28, height: size * 0.12),
                    isEnabled: pose.body.tipBend != 0 || pose.body.footPush != 0 || pose.body.baseCompression != 0
                )
                .rotationEffect(
                    .degrees(pose.body.rotation),
                    anchor: UnitPoint(x: bounds.midX / canvasSize, y: bounds.maxY / canvasSize)
                )
                .scaleEffect(
                    pose.body.uniformScale,
                    anchor: UnitPoint(x: bounds.midX / canvasSize, y: bounds.maxY / canvasSize)
                )
        }
    }
}

struct FlameBottle: View {
    let emotion: String?
    var width: CGFloat = 82

    var body: some View {
        ZStack {
            Image("WhisperJarBack")
                .resizable()
            FlameCharacter(emotion: emotion, size: width * 0.46)
                .offset(y: width * 0.18)
            Image("WhisperJarFront")
                .resizable()
            Image("WhisperJarCork")
                .resizable()
        }
        .frame(width: width, height: width * 119 / 82)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(emotion ?? "기쁨") 불꽃이 담긴 유리병")
    }
}
