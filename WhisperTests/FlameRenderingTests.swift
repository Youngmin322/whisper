import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Whisper

@MainActor
@Suite("기쁨 불꽃의 실제 렌더링 전환", .serialized)
struct FlameRenderingTests {
    @Test("좌우 착지 직전 화면은 정지 원본으로 이어지고 이전의 급격한 형태 전환을 제거한다", arguments: [-1.0, 1.0])
    func landingMatchesRestArtwork(direction: Double) async throws {
        let run = FlameHopRun(kind: .joy, startedAt: 0, from: CGPoint(x: 0.5, y: 0.5),
                              to: CGPoint(x: 0.5 + direction * 0.1, y: 0.5), stepDuration: 0.66, steps: 1)
        func pose(at time: Double) -> FlameHopPose {
            FlameHopMotion.sample(run: run, time: time, size: CGSize(width: 393, height: 590),
                                  restingAt: run.to, restingSince: run.endsAt, facing: CGFloat(direction),
                                  seed: 0, kind: .joy, reduceMotion: false)
        }
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 240, height: 240)
        let host = UIHostingController(rootView: artwork(pose(at: 0)))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }

        func capture(_ pose: FlameHopPose) async throws -> [UInt8] {
            host.rootView = artwork(pose)
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

        let rest = try await capture(pose(at: run.endsAt))
        let starting = try await capture(pose(at: 0))
        let almostLanded = pose(at: run.endsAt - 0.000001)
        let smoothLanding = try await capture(almostLanded)
        var oldLanding = almostLanded
        oldLanding.referenceBlend = 1
        let abruptLanding = try await capture(oldLanding)

        let coloredPixels = stride(from: 0, to: rest.count, by: 4).filter {
            rest[$0] > 200 && rest[$0 + 1] > 100 && rest[$0 + 1] < 230 && rest[$0 + 2] < 150
        }.count
        #expect(coloredPixels > 1_000)
        #expect(difference(starting, rest) < 0.002)
        #expect(difference(smoothLanding, rest) < 0.002)
        // Replaying the old last-frame behavior demonstrates the discontinuity.
        #expect(difference(abruptLanding, rest) > 0.01)
    }

    private func artwork(_ pose: FlameHopPose) -> some View {
        AnimatedFlameCharacter(emotion: "기쁨", pose: pose, size: 120)
            .frame(width: 240, height: 240)
            .background(Color.white)
            .preferredColorScheme(.light)
    }

    private func difference(_ first: [UInt8], _ second: [UInt8]) -> Double {
        var total = 0
        for index in first.indices where index % 4 != 3 {
            total += abs(Int(first[index]) - Int(second[index]))
        }
        return Double(total) / Double(first.count / 4 * 3 * 255)
    }
}
