import SwiftUI

struct FlameCharacter: View {
    let emotion: String?
    var size: CGFloat = 52

    private var assetName: String {
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
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
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
