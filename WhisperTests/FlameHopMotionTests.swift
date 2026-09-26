import CoreGraphics
import Testing
@testable import Whisper

@Suite("불꽃의 총총 걷기")
struct FlameHopMotionTests {
    private let field = CGSize(width: 393, height: 590)

    @Test("몸은 거의 뜨지 않고 아랫부분이 이동 방향으로 앞선다")
    func smallStrideWithTrailingTop() {
        let stride = FlameHopMotion.sample(seed: 0, time: 0.095, size: field, reduceMotion: false)

        #expect(stride.lift > 0 && stride.lift < 2)
        #expect(stride.bodyScaleY < 1.03)
        #expect(stride.facing == 1)
        #expect(stride.bodyLean < 0)
        #expect(stride.faceOffsetX < 0)
    }

    @Test("짧은 걸음을 세 번 잇고 잠깐 멈춘 뒤 다시 이동한다")
    func burstAndPause() {
        let first = FlameHopMotion.sample(seed: 0, time: 0.10, size: field, reduceMotion: false)
        let second = FlameHopMotion.sample(seed: 0, time: 0.29, size: field, reduceMotion: false)
        let pauseStart = FlameHopMotion.sample(seed: 0, time: 0.65, size: field, reduceMotion: false)
        let pauseEnd = FlameHopMotion.sample(seed: 0, time: 1.00, size: field, reduceMotion: false)
        let resumed = FlameHopMotion.sample(seed: 0, time: 1.20, size: field, reduceMotion: false)

        #expect(distance(first.groundPosition, second.groundPosition) > 2)
        #expect(pauseStart.groundPosition == pauseEnd.groundPosition)
        #expect(pauseStart.lift == 0 && pauseStart.bodyLean == 0)
        #expect(distance(pauseEnd.groundPosition, resumed.groundPosition) > 1)
    }

    @Test("화면 안에서 짧게 이동하고 걸음마다 작은 먼지가 생긴다")
    func shortStepsStayWithinField() {
        for seed in [0.0, 0.27, 0.61, 0.94] {
            for step in 0...100 {
                let time = Double(step) / 100 * (88 + seed * 10)
                let pose = FlameHopMotion.sample(seed: seed, time: time, size: field, reduceMotion: false)
                #expect(pose.groundPosition.x >= 44 && pose.groundPosition.x <= field.width - 44)
                #expect(pose.groundPosition.y >= 52 && pose.groundPosition.y <= field.height - 52)
            }
        }

        let start = FlameHopMotion.sample(seed: 0, time: 0, size: field, reduceMotion: false)
        let afterOneStep = FlameHopMotion.sample(seed: 0, time: 0.19, size: field, reduceMotion: false)
        let dust = FlameHopMotion.sample(seed: 0, time: 0.20, size: field, reduceMotion: false)
        #expect(distance(start.groundPosition, afterOneStep.groundPosition) < 10)
        #expect(dust.dustOpacity > 0 && dust.dustOpacity < 0.2)
    }

    @Test("움직임 줄이기에서는 몸과 위치가 정지한다")
    func reducedMotionIsStill() {
        let first = FlameHopMotion.sample(seed: 0.42, time: 0, size: field, reduceMotion: true)
        let later = FlameHopMotion.sample(seed: 0.42, time: 100, size: field, reduceMotion: true)
        #expect(first.groundPosition == later.groundPosition)
        #expect(first.lift == 0)
        #expect(first.bodyScaleX == 1 && first.bodyScaleY == 1)
        #expect(first.dustOpacity == 0)
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(second.x - first.x, second.y - first.y)
    }
}
