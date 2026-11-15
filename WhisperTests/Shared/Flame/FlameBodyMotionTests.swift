import CoreGraphics
import Foundation
import Metal
import Testing
@testable import Whisper

@Suite("감정별 불꽃 움직임")
struct FlameBodyMotionTests {
    private let field = CGSize(width: 393, height: 590)

    @Test("여섯 감정은 별도의 리듬과 박차 강도를 가진다")
    func profilesAreDistinct() {
        let kinds = FlameMotionKind.allCases
        #expect(Set(kinds.map { FlameMotionProfile.forKind($0).stepDuration }).count == 6)
        #expect(FlameMotionProfile.forKind(.joy).lift > FlameMotionProfile.forKind(.sadness).lift)
        #expect(FlameMotionProfile.forKind(.anger).stepDistance > FlameMotionProfile.forKind(.depression).stepDistance)
        #expect(FlameMotionProfile.forKind(.depression).pauseDuration > FlameMotionProfile.forKind(.joy).pauseDuration)
        #expect(FlameMotionProfile.forKind(.anxiety).pauseDuration > FlameMotionProfile.forKind(.anger).pauseDuration)
    }

    @Test("감정별 동작이 실제 홈 포즈에 연결된다")
    func homeUsesEmotion() {
        let joy = sample(kind: .joy, time: 0.22)
        let sadness = sample(kind: .sadness, time: 0.22)
        let anger = sample(kind: .anger, time: 0.22)
        #expect(joy.lift > sadness.lift)
        #expect(anger.body.rotation > sadness.body.rotation)
        #expect(joy.body.rotation > 0 && joy.body.stretch > 0)
        #expect(anger.body != joy.body)
    }

    @Test("기쁨은 좌우 어느 쪽으로 가든 진행 방향으로 기울고 끝은 뒤로 남는다", arguments: [-1.0, 1.0])
    func joyLeansIntoTravel(direction: Double) {
        let run = FlameHopRun(kind: .joy, startedAt: 0, from: CGPoint(x: 0.5, y: 0.5),
                              to: CGPoint(x: 0.5 + direction * 0.1, y: 0.5), stepDuration: 0.72, steps: 1)
        func pose(_ time: Double) -> FlameHopPose {
            FlameHopMotion.sample(run: run, time: time, size: field, restingAt: run.from,
                                  restingSince: 0, facing: CGFloat(direction), seed: 0, kind: .joy, reduceMotion: false)
        }
        let crouch = pose(0.12), launch = pose(0.14 + 0.38 * 0.2)
        #expect(crouch.body.rotation * direction > 0 && crouch.body.stretch < 0)
        #expect(launch.body.rotation * direction > crouch.body.rotation * direction)
        #expect(launch.body.tipBend * CGFloat(direction) < 0)
    }

    @Test("실제 생성한 기쁨은 원래 강도로 정점까지 뛰고 앞쪽 오프셋 없이 이동 경로로 나아간다")
    func generatedJoyUsesOriginalStrength() {
        let profile = FlameMotionProfile.forKind(.joy)
        for seed in [0.0, 0.11, 0.27, 0.61, 0.94] {
            for index in 0..<4 {
                let run = FlameHopMotion.makeRun(seed: seed, kind: .joy, index: index, at: 0,
                                                from: CGPoint(x: 0.5, y: 0.5), size: field)
                #expect(run.strength == 1)
                let style = FlameForwardHop.style(for: .joy)
                let apex = style.contactTime(stepDuration: run.stepDuration) - style.airDuration(stepDuration: run.stepDuration) / 2
                let pose = FlameHopMotion.sample(
                    run: run, time: apex, size: field, restingAt: run.from,
                    restingSince: 0, facing: 1, seed: seed, kind: .joy, reduceMotion: false
                )
                #expect(abs(pose.lift - profile.lift) < 0.000001)
                #expect(pose.lead == 0 && abs(pose.body.stretch) < 0.000001)
            }
        }
    }

    @Test("기쁨의 대기는 위치를 고정하고 작은 호흡과 고개 움직임만 사용한다")
    func restingJoyHasSubtleLife() {
        for seed in [0.0, 0.11, 0.27, 0.61, 0.94] {
            for tick in 0...120 {
                let pose = FlameHopMotion.sample(
                    run: nil, time: Double(tick) / 10, size: field,
                    restingAt: CGPoint(x: 0.5, y: 0.5), restingSince: 0,
                    facing: 1, seed: seed, kind: .joy, reduceMotion: false
                )
                #expect(abs(pose.body.tipBend) <= 0.012)
                #expect(pose.body.baseCompression >= -0.02 && pose.body.baseCompression <= 0.03)
                #expect(abs(pose.body.rotation) <= 1.8)
                #expect(pose.body.footPush == 0 && pose.body.uniformScale == 1)
                #expect(pose.blinkScale >= 0.08 && pose.blinkScale <= 1)
                #expect(pose.lift == 0 && pose.lead == 0 && !pose.isMoving)
            }
        }
    }

    @Test("움직임 줄이기는 정지 그림이고 모든 감정은 대기 중에 작게 호흡한다")
    func restAndReducedMotion() {
        for kind in FlameMotionKind.allCases {
            let reduced = sample(kind: kind, time: 1, reduceMotion: true)
            #expect(reduced.body == .rest)
            #expect(reduced.lift == 0 && reduced.blinkScale == 1)
            let resting = sample(kind: kind, time: 5)
            #expect(!resting.isMoving)
            #expect(abs(resting.body.tipBend) <= 0.012)
            #expect(resting.body.footPush == 0)
            #expect(resting.body.baseCompression >= -0.02 && resting.body.baseCompression <= 0.03)
            #expect(abs(resting.body.rotation) <= 1.8 && resting.body.uniformScale == 1)
        }
    }

    @Test("몸 변형은 끝과 바닥만 사용하고 중앙 얼굴 영역을 보존한다")
    func faceSafeMotionRanges() throws {
        for kind in FlameMotionKind.allCases {
            let profile = FlameMotionProfile.forKind(kind)
            let run = FlameHopRun(kind: kind, startedAt: 0, from: CGPoint(x: 0.5, y: 0.5),
                                  to: CGPoint(x: 0.6, y: 0.5), stepDuration: profile.stepDuration, steps: 1)
            for tick in 0...100 {
                let pose = FlameHopMotion.sample(run: run, time: run.duration * Double(tick) / 100, size: field,
                                                 restingAt: run.from, restingSince: -10, facing: 1, seed: 0,
                                                 kind: kind, reduceMotion: false)
                #expect(abs(pose.body.tipBend) <= 0.131)
                #expect(abs(pose.body.rotation) <= 30)
                #expect(pose.body.stretch > -0.3 && pose.body.stretch < 0.25)
            }
        }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeDefaultLibrary(bundle: .main)
        #expect(library.functionNames.contains("flameBodyWarp"))
        #expect(!library.functionNames.contains("flameReferenceWarp"))
        #expect(library.functionNames.contains("flameBlink"))
    }

    @MainActor
    @Test("여섯 승인 캐릭터의 실제 몸 영역을 찾는다")
    func artworkBoundsAdaptToSkinAndSize() {
        for emotion in WhisperEmotion.selectableCases {
            let appearance = FlameAppearance.resolve(emotion.rawValue)
            let small = appearance.rigBounds(characterSize: 48, canvasSize: 80)
            let large = appearance.rigBounds(characterSize: 96, canvasSize: 160)
            #expect(small.width > 25 && small.height > 25)
            #expect(small.minX >= 0 && small.maxX <= 80)
            #expect(small.minY >= 0 && small.maxY <= 80)
            #expect(abs(large.minX - small.minX * 2) < 0.001)
            #expect(abs(large.height - small.height * 2) < 0.001)
            let eyes = appearance.blinkEyes(characterSize: 48, canvasSize: 80)
            #expect(eyes.count == (emotion == .calm ? 0 : 2))
            #expect(eyes.allSatisfy { small.contains($0.ellipse) })
            #expect(eyes.allSatisfy { ($0.browGuardStart == nil) == ($0.browGuardEnd == nil) })
        }
    }

    private func sample(kind: FlameMotionKind, time: Double, reduceMotion: Bool = false) -> FlameHopPose {
        let profile = FlameMotionProfile.forKind(kind)
        let run = FlameHopRun(kind: kind, startedAt: 0, from: CGPoint(x: 0.5, y: 0.5),
                              to: CGPoint(x: 0.55, y: 0.5), stepDuration: profile.stepDuration,
                              steps: profile.stepsPerBurst)
        return FlameHopMotion.sample(run: run, time: time, size: field, restingAt: run.from,
                                     restingSince: 0, facing: 1, seed: 0, kind: kind, reduceMotion: reduceMotion)
    }
}
