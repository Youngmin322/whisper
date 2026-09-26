import SwiftUI

struct FlameCharacter: View {
    let emotion: String?
    var size: CGFloat = 52

    static func assetName(for emotion: String?) -> String {
        switch emotion ?? "" {
        case WhisperEmotion.calm.rawValue: "FlameCalm"
        case WhisperEmotion.tired.rawValue: "FlameTired"
        case WhisperEmotion.excitement.rawValue: "FlameExcited"
        case WhisperEmotion.anxiety.rawValue: "FlameAnxious"
        case "속상": "FlameUpset"
        default: "FlameJoy"
        }
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

    private var assetName: String { FlameCharacter.assetName(for: emotion) }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.whisperTextSecondary.opacity(0.10))
                .frame(width: size * 0.48 * pose.shadowScale, height: 5)
                .offset(y: size * 0.49)

            Image("\(assetName)Body")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size * 1.1)
                .distortionEffect(
                    ShaderLibrary.flameFlex(
                        .float2(Float(size), Float(size * 1.1)),
                        .float(Float(pose.lowerBend))
                    ),
                    maxSampleOffset: CGSize(width: 20, height: 0)
                )
                .scaleEffect(x: pose.bodyScaleX, y: pose.bodyScaleY, anchor: .top)
                .rotationEffect(.degrees(pose.bodyLean), anchor: .top)
                .offset(y: pose.bodyOffsetY - pose.lift)

            Image("\(assetName)Face")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size * 1.1)
                .rotation3DEffect(.degrees(pose.faceYaw), axis: (x: 0, y: 1, z: 0))
                .offset(
                    x: pose.faceOffsetX,
                    y: pose.faceOffsetY + pose.bodyOffsetY - pose.lift
                )
        }
        .frame(width: size, height: size * 1.1)
        .accessibilityHidden(true)
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
