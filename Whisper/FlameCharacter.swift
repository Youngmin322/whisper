import SwiftUI

struct FlameCharacter: View {
    let emotion: String?
    var size: CGFloat = 52

    static func assetName(for emotion: String?) -> String {
        switch emotion ?? "" {
        case WhisperEmotion.calm.rawValue: "EmotionFlameCalm"
        case WhisperEmotion.tired.rawValue: "FlameTired"
        case WhisperEmotion.excitement.rawValue: "FlameExcited"
        case WhisperEmotion.anxiety.rawValue: "EmotionFlameAnxiety"
        case "우울": "EmotionFlameDepression"
        case "분노": "EmotionFlameAnger"
        case "슬픔", "속상": "EmotionFlameSadness"
        default: "EmotionFlameJoy"
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
    private var usesLegacyAnimation: Bool {
        emotion == WhisperEmotion.tired.rawValue || emotion == WhisperEmotion.excitement.rawValue
    }
    private var canvasSize: CGFloat { size * 5 / 3 }
    private var stepFrame: String { String(format: "%02d", pose.frameIndex) }
    private var faceScale: CGFloat {
        switch pose.frameIndex {
        case 8...10: 0.82
        case 11...12: 0.90
        default: 1
        }
    }

    private var palette: (outer: Color, inner: Color) {
        switch emotion ?? "" {
        case WhisperEmotion.calm.rawValue:
            (flameColor(0xDB9D96), flameColor(0xFAD3AE))
        case WhisperEmotion.tired.rawValue:
            (flameColor(0x87B3AA), flameColor(0xD6E3C6))
        case WhisperEmotion.excitement.rawValue:
            (flameColor(0xEA8060), flameColor(0xFFC16D))
        case WhisperEmotion.anxiety.rawValue:
            (flameColor(0xB7A6CC), flameColor(0xE1D5EB))
        case "속상":
            (flameColor(0x9F9FCB), flameColor(0xD9CDEA))
        default:
            (flameColor(0xF0A143), flameColor(0xFFD477))
        }
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.whisperTextSecondary.opacity(0.10))
                .frame(width: size * 0.48 * pose.shadowScale, height: 5)
                .offset(y: size * 0.50)

            ZStack {
                if usesLegacyAnimation {
                    Image("FlameStepOuter\(stepFrame)")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(palette.outer)
                    Image("FlameStepInner\(stepFrame)")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(palette.inner)
                    Image("\(assetName)Face")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size * 1.1)
                        .scaleEffect(faceScale, anchor: UnitPoint(x: 0.5, y: 0.68))
                        .rotationEffect(.degrees(pose.faceRotation), anchor: UnitPoint(x: 0.5, y: 0.68))
                        .offset(y: -1.5)
                } else {
                    FlameCharacter(emotion: emotion, size: size)
                        .scaleEffect(faceScale, anchor: .bottom)
                        .rotationEffect(.degrees(pose.faceRotation), anchor: .bottom)
                        .offset(y: -1.5)
                }
            }
            .frame(width: canvasSize, height: canvasSize)
            .scaleEffect(x: pose.facing, y: 1)
            .offset(x: pose.facing * pose.lead, y: -pose.lift)
        }
        .frame(width: canvasSize, height: canvasSize)
        .accessibilityHidden(true)
    }
}

private func flameColor(_ hex: UInt32) -> Color {
    Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255
    )
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
