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
        let bounds = FlameAppearance.resolve(emotion).rigBounds(characterSize: size, canvasSize: canvasSize)
        ZStack {
            Ellipse()
                .fill(Color.whisperTextSecondary.opacity(0.10))
                .frame(width: size * 0.48 * pose.shadowScale, height: 5)
                .offset(y: size * 0.50)
                .opacity(shadowOpacity)

            animatedArtwork(bounds: bounds)
                // Joy mirrors its motion, not the approved asymmetric artwork.
                .scaleEffect(x: motionKind == .joy ? 1 : pose.facing, y: 1)
                .offset(x: pose.facing * pose.lead, y: -pose.lift - 1.5)
        }
        .frame(width: canvasSize, height: canvasSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func animatedArtwork(bounds: CGRect) -> some View {
        if motionKind == .joy && (!pose.isMoving || pose.referenceBlend == 0) {
            // Rest uses the approved image itself, without layer reconstruction or deformation.
            FlameCharacter(emotion: emotion, size: size)
                .frame(width: canvasSize, height: canvasSize)
        } else if motionKind == .joy {
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
                            .floatArray(reference.mapping),
                            .float(Float(pose.referenceBlend)),
                            .float(Float(pose.facing))
                        ),
                        maxSampleOffset: CGSize(width: size * 0.8, height: size * 0.8),
                        isEnabled: pose.referenceBlend > 0
                    )

                Image("EmotionFlameJoyFace")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size * 1.1)
                    .scaleEffect(1 + (reference.faceScale - 1) * pose.referenceBlend,
                                 anchor: UnitPoint(x: 0.5, y: 0.68))
                    .rotationEffect(.degrees(reference.faceRotation * Double(pose.referenceBlend * pose.facing)),
                                    anchor: UnitPoint(x: 0.5, y: 0.68))
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
