import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("기쁨 불꽃의 실제 렌더링 전환", .serialized)
struct FlameRenderingTests {
    @Test("좌우 이동의 시작·착지·긴 휴식과 움직임 줄이기는 반전하지 않은 승인 원본으로 이어진다", arguments: [-1.0, 1.0])
    func landingMatchesRestArtwork(direction: Double) async throws {
        let run = FlameHopRun(kind: .joy, startedAt: 0, from: CGPoint(x: 0.5, y: 0.5),
                              to: CGPoint(x: 0.5 + direction * 0.1, y: 0.5), stepDuration: 0.66, steps: 1)
        func pose(at time: Double, activeRun: FlameHopRun? = nil, reduceMotion: Bool = false) -> FlameHopPose {
            FlameHopMotion.sample(run: activeRun, time: time, size: CGSize(width: 393, height: 590),
                                  restingAt: run.to, restingSince: run.endsAt, facing: CGFloat(direction),
                                  seed: 0, kind: .joy, reduceMotion: reduceMotion)
        }
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 240, height: 240)
        let host = UIHostingController(rootView: artwork(pose(at: 0, activeRun: run)))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }

        func capture(_ view: AnyView) async throws -> [UInt8] {
            host.rootView = view
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            // Allow the Metal-backed SwiftUI distortion to reach the render server.
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
            pose(at: run.endsAt + 1),
            pose(at: run.endsAt + 12),
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
        let almostLanded = pose(at: run.endsAt - 0.000001, activeRun: run)
        var oldLanding = almostLanded
        oldLanding.referenceBlend = 1
        let abruptLanding = try await capture(artwork(oldLanding))
        #expect(difference(abruptLanding, approved) > 0.01)
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
