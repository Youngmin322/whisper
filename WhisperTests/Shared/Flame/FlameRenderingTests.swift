import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("불꽃의 실제 렌더링 전환", .serialized)
struct FlameRenderingTests {
    @Test("좌우 이동의 시작·착지와 움직임 줄이기는 반전하지 않은 승인 원본으로 이어진다", arguments: [-1.0, 1.0])
    func landingMatchesRestArtwork(direction: Double) async throws {
        let run = FlameHopRun(kind: .joy, startedAt: 0, from: CGPoint(x: 0.5, y: 0.5),
                              to: CGPoint(x: 0.5 + direction * 0.1, y: 0.5), stepDuration: 0.66, steps: 1)
        func pose(at time: Double, activeRun: FlameHopRun? = nil, reduceMotion: Bool = false) -> FlameHopPose {
            FlameHopMotion.sample(run: activeRun, time: time, size: CGSize(width: 393, height: 590),
                                  restingAt: run.to, restingSince: run.endsAt, facing: CGFloat(direction),
                                  seed: 0, kind: .joy, reduceMotion: reduceMotion)
        }
        let renderer = try Renderer()
        defer { renderer.close() }

        func capture(_ view: AnyView) async throws -> [UInt8] {
            try await renderer.capture(view)
        }

        // The approved image is an independent baseline: comparing two poses alone
        // also passes when both incorrectly mirror the original.
        let approved = try await capture(originalArtwork(mirrored: false))
        let mirrored = try await capture(originalArtwork(mirrored: true))
        let coloredPixels = stride(from: 0, to: approved.count, by: 4).filter {
            approved[$0] > 200 && approved[$0 + 1] > 100 && approved[$0 + 1] < 230 && approved[$0 + 2] < 150
        }.count
        #expect(coloredPixels > 1_000)
        #expect(difference(approved, mirrored) > 0.01)

        let settledPoses = [
            pose(at: 0, activeRun: run),
            pose(at: run.endsAt - 0.000001, activeRun: run),
            pose(at: run.endsAt, activeRun: run),
            pose(at: run.stepDuration * 0.52, activeRun: run, reduceMotion: true)
        ]
        for settled in settledPoses {
            let rendered = try await capture(artwork(settled))
            #expect(difference(rendered, approved) < 0.002)
            #expect(difference(rendered, mirrored) > 0.01)
        }

        // Keep actual motion on both sides; disabling the animation would also
        // make every settled pose match the approved image.
        let moving = pose(at: run.stepDuration * 0.52, activeRun: run)
        let movingPixels = try await capture(artwork(moving))
        #expect(difference(movingPixels, approved) > 0.01)

        // Idle now breathes, but keeps the approved orientation and only moves subtly.
        let idle = try await capture(artwork(pose(at: run.endsAt + 1)))
        #expect(difference(idle, approved) < 0.02)
        #expect(difference(idle, mirrored) > 0.01)

        let boundary = run.flightDuration * 8 / 16
        let before = try await capture(artwork(pose(at: boundary - 0.000001, activeRun: run)))
        let after = try await capture(artwork(pose(at: boundary + 0.000001, activeRun: run)))
        #expect(difference(before, after) < 0.002)
    }

    @Test("모든 감정의 착지 압축·대기 호흡·눈 깜빡임이 실제 화면 픽셀에 반영된다",
          arguments: ["기쁨", "평온", "불안", "우울", "분노", "슬픔"])
    func cushionAndIdleReachRenderer(emotion: String) async throws {
        let kind = FlameMotionKind.resolve(emotion)
        let origin = CGPoint(x: 0.5, y: 0.5)
        let run = FlameHopRun(kind: kind, startedAt: 0, from: origin,
                              to: CGPoint(x: 0.6, y: 0.5), stepDuration: 0.66, steps: 1)
        let seed = 0.27
        func pose(time: Double, run: FlameHopRun? = nil) -> FlameHopPose {
            FlameHopMotion.sample(run: run, time: time, size: CGSize(width: 393, height: 590),
                                  restingAt: origin, restingSince: 0, facing: 1, seed: seed,
                                  kind: kind, reduceMotion: false)
        }
        let renderer = try Renderer()
        defer { renderer.close() }
        func capture(_ pose: FlameHopPose) async throws -> [UInt8] {
            try await renderer.capture(AnyView(
                AnimatedFlameCharacter(emotion: emotion, pose: pose, size: 120)
                    .frame(width: 240, height: 240)
                    .background(Color.white)
                    .preferredColorScheme(.light)
            ))
        }

        let cushion = pose(time: run.flightDuration + 0.04, run: run)
        var uncushioned = cushion
        uncushioned.body.baseCompression = 0
        uncushioned.body.stretch = 0
        #expect(difference(try await capture(cushion), try await capture(uncushioned)) > 0.00001)

        let breathing = pose(time: 1)
        var still = breathing
        still.body.baseCompression = 0
        #expect(difference(try await capture(breathing), try await capture(still)) > 0.00001)

        let blinkAt = 4 + FlameHopMotion.random(seed: seed, index: 0, channel: 15) + 0.075
        let closed = pose(time: blinkAt)
        var open = closed
        open.blinkScale = 1
        // Calm's approved eyes are already closed, so its blink must leave the artwork untouched.
        let blinkDifference = difference(try await capture(closed), try await capture(open))
        #expect(kind == .calm ? blinkDifference == 0 : blinkDifference > 0.00001)
    }

    @MainActor
    private final class Renderer {
        private let window: UIWindow
        private let host = UIHostingController(rootView: AnyView(Color.white))

        init() throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 240, height: 240)
            window.rootViewController = host
            window.isHidden = false
        }

        func close() {
            window.isHidden = true
            window.rootViewController = nil
        }

        func capture(_ view: AnyView) async throws -> [UInt8] {
            host.rootView = view
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            // Wait for the real Metal-backed SwiftUI render, rather than inspecting pose values alone.
            try await Task.sleep(for: .milliseconds(100))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            var drewHierarchy = false
            let image = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240), format: format).image { _ in
                drewHierarchy = host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            #expect(drewHierarchy)
            let cgImage = try #require(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: 240 * 240 * 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try #require(CGContext(
                    data: buffer.baseAddress, width: 240, height: 240, bitsPerComponent: 8,
                    bytesPerRow: 240 * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 240, height: 240))
            }
            return bytes
        }
    }

    private func artwork(_ pose: FlameHopPose) -> AnyView {
        AnyView(AnimatedFlameCharacter(emotion: "기쁨", pose: pose, size: 120)
            .frame(width: 240, height: 240)
            .background(Color.white)
            .preferredColorScheme(.light))
    }

    private func originalArtwork(mirrored: Bool) -> AnyView {
        AnyView(FlameCharacter(emotion: "기쁨", size: 120)
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
            .offset(y: -1.5)
            .frame(width: 240, height: 240)
            .background(Color.white)
            .preferredColorScheme(.light))
    }

    private func difference(_ first: [UInt8], _ second: [UInt8]) -> Double {
        var total = 0
        for index in first.indices where index % 4 != 3 {
            total += abs(Int(first[index]) - Int(second[index]))
        }
        return Double(total) / Double(first.count / 4 * 3 * 255)
    }
}
