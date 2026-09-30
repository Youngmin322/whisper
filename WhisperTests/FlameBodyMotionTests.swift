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
        #expect(FlameMotionProfile.forKind(.anger).lead > FlameMotionProfile.forKind(.calm).lead)
        #expect(FlameMotionProfile.forKind(.depression).pauseDuration > FlameMotionProfile.forKind(.joy).pauseDuration)
        #expect(FlameMotionProfile.forKind(.anxiety).pauseDuration > FlameMotionProfile.forKind(.anger).pauseDuration)
    }

    @Test("감정별 동작이 실제 홈 포즈에 연결된다")
    func homeUsesEmotion() {
        let joy = sample(kind: .joy, time: 0.22)
        let sadness = sample(kind: .sadness, time: 0.22)
        let anger = sample(kind: .anger, time: 0.22)
        #expect(joy.lift > sadness.lift)
        #expect(anger.lead > sadness.lead)
        #expect(joy.body == .rest)
        #expect(anger.body != joy.body)
    }

    @Test("기쁨은 GitHub의 16프레임 리듬과 얼굴 자세를 그대로 사용한다")
    func joyUsesCommittedReferenceGait() {
        let bend = sample(kind: .joy, time: 0.66 * 0.25)
        let launch = sample(kind: .joy, time: 0.66 * 0.52)
        let landing = sample(kind: .joy, time: 0.66 * 0.83)

        #expect(bend.frameIndex == 4 && bend.faceRotation == -12)
        #expect(launch.frameIndex == 8 && launch.faceRotation == -28)
        #expect(landing.frameIndex == 13 && landing.faceRotation == 0)
        #expect(abs(launch.lift - 5.4) < 0.02)
        #expect(FlameReferenceRig.frames.count == 16)
        #expect(FlameReferenceRig.frames[8].faceScale == 0.82)
    }

    @Test("움직임 줄이기는 정지 그림이고 휴식 중에는 작은 끝 움직임만 남는다")
    func restAndReducedMotion() {
        for kind in FlameMotionKind.allCases {
            let reduced = sample(kind: kind, time: 1, reduceMotion: true)
            #expect(reduced.body == .rest)
            #expect(reduced.lift == 0)
            let resting = sample(kind: kind, time: 5)
            #expect(!resting.isMoving)
            #expect(abs(resting.body.tipBend) <= 0.010)
            #expect(resting.body.footPush == 0 && resting.body.baseCompression == 0)
            #expect(resting.body.rotation == 0 && resting.body.uniformScale == 1)
        }
    }

    @Test("몸 변형은 끝과 바닥만 사용하고 중앙 얼굴 영역을 보존한다")
    func faceSafeMotionRanges() throws {
        for kind in FlameMotionKind.allCases {
            for tick in 0...100 {
                let pose = FlameBodyMotion.sample(kind: kind, phase: Double(tick) / 100)
                #expect(abs(pose.tipBend) <= 0.131)
                #expect(abs(pose.footPush) <= 0.071)
                #expect(pose.baseCompression <= 0.111)
                #expect(pose.uniformScale > 0)
            }
        }
        let device = try #require(MTLCreateSystemDefaultDevice())
        let library = try device.makeDefaultLibrary(bundle: .main)
        #expect(library.functionNames.contains("flameBodyWarp"))
        #expect(library.functionNames.contains("flameReferenceWarp"))
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
