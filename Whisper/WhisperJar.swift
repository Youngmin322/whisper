//
//  WhisperJar.swift
//  Whisper
//
//  Created by Youngmin Cho on 8/19/26.
//

import SwiftUI
import WhisperDesignSystem

struct WhisperJarAnimation: View {
    enum Size {
        case hero
        case small
        case home
        case today

        var width: CGFloat {
            switch self {
            case .hero:
                120
            case .small:
                70
            case .home:
                50
            case .today:
                104
            }
        }

        var height: CGFloat {
            switch self {
            case .hero:
                140
            case .small:
                82
            case .home:
                60
            case .today:
                122
            }
        }
    }

    let size: Size

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFlameAnimating = false

    var body: some View {
        ZStack {
            // 유리병 + 코르크마개
            Image.jar
                .resizable()
                .scaledToFit()
                .frame(
                    width: size.width,
                    height: size.height
                )

            // 불꽃 캐릭터
            Image.whisperFlame
                .resizable()
                .scaledToFit()
                .frame(
                    width: size.width * 0.40,
                    height: size.height * 0.55
                )
                .scaleEffect(
                    x: isFlameAnimating ? 1.02 : 0.98,
                    y: isFlameAnimating ? 1.04 : 0.96
                )
                .rotationEffect(
                    .degrees(
                        isFlameAnimating ? 2 : -2
                    )
                )
                .offset(
                    y: isFlameAnimating ? 8 : 10
                )
        }
        .frame(
            width: size.width,
            height: size.height
        )
        .onAppear {
            isFlameAnimating = !reduceMotion
        }
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
            value: isFlameAnimating
        )
    }
}

#Preview("Whisper Jar") {
    ZStack {
        Color.whisperBackground
            .ignoresSafeArea()

        VStack(spacing: 40) {
            WhisperJarAnimation(size: .hero)
            WhisperJarAnimation(size: .small)
        }
    }
}

#Preview("Whisper Jar") {
    ZStack {
        Color.whisperBackground
            .ignoresSafeArea()
        
            WhisperJarAnimation(size: .hero)
    }
}
