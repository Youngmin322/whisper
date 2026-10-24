//
//  WhisperJar.swift
//  Whisper
//
//  Created by Youngmin Cho on 8/19/26.
//

import SwiftUI

struct WhisperJarAnimation: View {
    enum Size {
        case hero
        case small
        case home

        var width: CGFloat {
            switch self {
            case .hero:
                120
            case .small:
                70
            case .home:
                50
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
            }
        }
    }

    let size: Size

    @State private var isFlameAnimating = false

    var body: some View {
        let width = min(size.width, size.height / WhisperJarDesign.heightToWidth)
        let jar = OriginalWhisperJar(width: width)
        ZStack {
            jar.back

            // 불꽃 캐릭터
            FlameCharacter(emotion: nil, size: width * 0.40)
                .frame(
                    width: width * 0.40,
                    height: width * 0.55
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
                    y: width * 0.13 + (isFlameAnimating ? -1 : 1)
                )
            jar.front
        }
        .frame(
            width: size.width,
            height: size.height
        )
        .onAppear {
            isFlameAnimating = true
        }
        .animation(
            .easeInOut(duration: 0.9)
                .repeatForever(autoreverses: true),
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
