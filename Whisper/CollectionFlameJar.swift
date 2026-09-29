//
//  CollectionFlameJar.swift
//  Whisper
//

import SwiftUI

struct CollectionFlameJar: View {
    private enum DisplayState {
        case empty
        case single
        case multiple
    }

    private static let designSize = CGSize(width: 112, height: 149)

    let storedFlameCount: Int
    var width: CGFloat = 72
    var emotions: [String?] = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var height: CGFloat {
        width * Self.designSize.height / Self.designSize.width
    }

    private var displayState: DisplayState {
        switch storedFlameCount {
        case ...0:
            .empty
        case 1:
            .single
        default:
            .multiple
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            GeometryReader { geometry in
                let scaleX = geometry.size.width / Self.designSize.width
                let scaleY = geometry.size.height / Self.designSize.height
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack(alignment: .topLeading) {
                    fixedAsset(
                        "CollectionJarBody",
                        frame: CGRect(x: 13.43, y: 29.23, width: 87.85, height: 118.10),
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                    fixedAsset(
                        "CollectionJarInnerGlass",
                        frame: CGRect(x: 21.74, y: 36.62, width: 71.46, height: 101.40),
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                    fixedAsset(
                        "CollectionJarNeck",
                        frame: CGRect(x: 26.02, y: 22.81, width: 59.31, height: 15.83),
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                    fixedAsset(
                        "CollectionJarCork",
                        frame: CGRect(x: 31.34, y: 0, width: 50.75, height: 26),
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                    fixedAsset(
                        "CollectionJarCorkHighlight",
                        frame: CGRect(x: 36.02, y: 2.95, width: 41.78, height: 15.41),
                        scaleX: scaleX,
                        scaleY: scaleY
                    )

                    floatingFlames(
                        time: time,
                        scaleX: scaleX,
                        scaleY: scaleY
                    )

                    fixedAsset(
                        "CollectionJarGlassHighlight",
                        frame: CGRect(x: 25.96, y: 53.37, width: 10.86, height: 55.50),
                        scaleX: scaleX,
                        scaleY: scaleY
                    )
                }
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func floatingFlames(
        time: TimeInterval,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> some View {
        switch displayState {
        case .empty:
            EmptyView()

        case .single:
            movingAsset(
                flameAsset(at: 0),
                frame: CGRect(x: 43, y: 73, width: 26, height: 36),
                baseRotation: 0,
                yAmplitude: 4,
                rotationAmplitude: 2,
                duration: 2.6,
                phase: 0,
                time: time,
                scaleX: scaleX,
                scaleY: scaleY
            )

        case .multiple:
            movingAsset(
                flameAsset(at: 0),
                frame: CGRect(x: 60, y: 73, width: 26, height: 36),
                baseRotation: -4,
                yAmplitude: 4,
                rotationAmplitude: 2,
                duration: 2.6,
                phase: 0,
                time: time,
                scaleX: scaleX,
                scaleY: scaleY
            )
            movingAsset(
                flameAsset(at: 1),
                frame: CGRect(x: 28, y: 50, width: 22, height: 31),
                baseRotation: 7,
                yAmplitude: 6,
                rotationAmplitude: 3,
                duration: 3.1,
                phase: 2.1,
                time: time,
                scaleX: scaleX,
                scaleY: scaleY
            )
            movingAsset(
                flameAsset(at: 2),
                frame: CGRect(x: 33, y: 105, width: 18, height: 25),
                baseRotation: -8,
                yAmplitude: 5,
                rotationAmplitude: 4,
                duration: 2.3,
                phase: 4.2,
                time: time,
                scaleX: scaleX,
                scaleY: scaleY
            )
        }
    }

    private func flameAsset(at index: Int) -> String {
        let emotion = emotions.indices.contains(index) ? emotions[index] : nil
        return FlameCharacter.assetName(for: emotion)
    }

    private func fixedAsset(
        _ name: String,
        frame: CGRect,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> some View {
        Image(name)
            .resizable()
            .frame(
                width: frame.width * scaleX,
                height: frame.height * scaleY
            )
            .position(
                x: frame.midX * scaleX,
                y: frame.midY * scaleY
            )
            .accessibilityHidden(true)
    }

    private func movingAsset(
        _ name: String,
        frame: CGRect,
        baseRotation: Double,
        yAmplitude: CGFloat,
        rotationAmplitude: Double,
        duration: TimeInterval,
        phase: Double,
        time: TimeInterval,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> some View {
        let progress = reduceMotion
            ? CGFloat.zero
            : CGFloat(sin((time / duration) * .pi * 2 + phase))

        return Image(name)
            .resizable()
            .scaledToFit()
            .frame(
                width: frame.width * scaleX,
                height: frame.height * scaleY
            )
            .rotationEffect(
                .degrees(baseRotation + Double(progress) * rotationAmplitude)
            )
            .position(
                x: frame.midX * scaleX,
                y: frame.midY * scaleY
            )
            .offset(y: progress * yAmplitude * scaleY)
            .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        switch displayState {
        case .empty:
            "비어 있는 불꽃 유리병"
        case .single:
            "불꽃 한 개가 떠다니는 유리병"
        case .multiple:
            "\(storedFlameCount)개의 불꽃을 간직한 유리병"
        }
    }
}

#Preview("Collection Flame Jar States") {
    HStack(spacing: 24) {
        ForEach([0, 1, 2, 8], id: \.self) { count in
            VStack(spacing: 8) {
                CollectionFlameJar(storedFlameCount: count)
                Text("\(count)개")
                    .font(.caption)
            }
        }
    }
    .padding()
}
