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

    private static let designSize = WhisperJarDesign.size

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
                    OriginalWhisperJar(width: geometry.size.width).back

                    floatingFlames(
                        time: time,
                        scaleX: scaleX,
                        scaleY: scaleY
                    )

                    OriginalWhisperJar(width: geometry.size.width).front
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
                frame: CGRect(x: 182, y: 382, width: 128, height: 176),
                baseRotation: 0,
                yAmplitude: 18,
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
                frame: CGRect(x: 265, y: 375, width: 110, height: 150),
                baseRotation: -4,
                yAmplitude: 18,
                rotationAmplitude: 2,
                duration: 2.6,
                phase: 0,
                time: time,
                scaleX: scaleX,
                scaleY: scaleY
            )
            movingAsset(
                flameAsset(at: 1),
                frame: CGRect(x: 160, y: 266, width: 108, height: 148),
                baseRotation: 7,
                yAmplitude: 26,
                rotationAmplitude: 3,
                duration: 3.1,
                phase: 2.1,
                time: time,
                scaleX: scaleX,
                scaleY: scaleY
            )
            movingAsset(
                flameAsset(at: 2),
                frame: CGRect(x: 156, y: 560, width: 88, height: 120),
                baseRotation: -8,
                yAmplitude: 22,
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
            String(localized: "비어 있는 불꽃 유리병")
        case .single:
            String(localized: "불꽃 한 개가 떠다니는 유리병")
        case .multiple:
            String(localized: "\(storedFlameCount)개의 불꽃을 간직한 유리병")
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
