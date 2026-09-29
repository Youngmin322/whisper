import CoreGraphics
import Testing
@testable import Whisper

@Suite("참고 영상 기반 불꽃 걸음")
struct FlameHopMotionTests {
    private let field = CGSize(width: 393, height: 590)

    @Test("둥근 몸이 앞서고 불꽃 끝이 뒤따르는 프레임을 순서대로 보여준다")
    func referenceFramesAdvance() {
        let start = FlameHopMotion.sample(seed: 0, time: 0, size: field, reduceMotion: false)
        let bend = FlameHopMotion.sample(seed: 0, time: 0.66 * 0.25, size: field, reduceMotion: false)
        let launch = FlameHopMotion.sample(seed: 0, time: 0.66 * 0.52, size: field, reduceMotion: false)
        let landing = FlameHopMotion.sample(seed: 0, time: 0.66 * 0.83, size: field, reduceMotion: false)

        #expect(start.frameIndex == 0)
        #expect(bend.frameIndex == 4)
        #expect(launch.frameIndex == 8)
        #expect(landing.frameIndex == 13)
        #expect(launch.lead > bend.lead)
        #expect(launch.lift > 4)
        #expect(landing.lift < launch.lift)
        #expect(distance(start.groundPosition, landing.groundPosition) > 5)
    }

    @Test("세 걸음을 잇고 잠깐 쉬었다가 다시 이동한다")
    func burstAndPause() {
        let first = FlameHopMotion.sample(seed: 0, time: 0.33, size: field, reduceMotion: false)
        let second = FlameHopMotion.sample(seed: 0, time: 0.99, size: field, reduceMotion: false)
        let pauseStart = FlameHopMotion.sample(seed: 0, time: 2.02, size: field, reduceMotion: false)
        let pauseEnd = FlameHopMotion.sample(seed: 0, time: 2.20, size: field, reduceMotion: false)
        let resumed = FlameHopMotion.sample(seed: 0, time: 2.40, size: field, reduceMotion: false)

        #expect(distance(first.groundPosition, second.groundPosition) > 5)
        #expect(pauseStart.groundPosition == pauseEnd.groundPosition)
        #expect(pauseStart.frameIndex == 0 && pauseStart.lift == 0)
        #expect(distance(pauseEnd.groundPosition, resumed.groundPosition) > 1)
    }

    @Test("불꽃은 화면 안을 이동하고 바닥을 박찰 때 작은 먼지를 만든다")
    func staysInFieldWithDust() {
        for seed in [0.0, 0.27, 0.61, 0.94] {
            for step in 0...100 {
                let time = Double(step) / 100 * (44 + seed * 8)
                let pose = FlameHopMotion.sample(seed: seed, time: time, size: field, reduceMotion: false)
                #expect(pose.groundPosition.x >= 44 && pose.groundPosition.x <= field.width - 44)
                #expect(pose.groundPosition.y >= 52 && pose.groundPosition.y <= field.height - 52)
            }
        }

        let dust = FlameHopMotion.sample(seed: 0, time: 0.66 * 0.42, size: field, reduceMotion: false)
        #expect(dust.dustOpacity > 0 && dust.dustOpacity < 0.24)
    }

    @Test("움직임 줄이기에서는 첫 프레임과 위치가 고정된다")
    func reducedMotionIsStill() {
        let first = FlameHopMotion.sample(seed: 0.42, time: 0, size: field, reduceMotion: true)
        let later = FlameHopMotion.sample(seed: 0.42, time: 100, size: field, reduceMotion: true)
        #expect(first.groundPosition == later.groundPosition)
        #expect(first.frameIndex == 0)
        #expect(first.lift == 0 && first.lead == 0)
        #expect(first.dustOpacity == 0)
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(second.x - first.x, second.y - first.y)
    }
}
