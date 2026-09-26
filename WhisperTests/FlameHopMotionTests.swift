import CoreGraphics
import Testing
@testable import Whisper

@Suite("불꽃의 연속 걸음")
struct FlameHopMotionTests {
    private let field = CGSize(width: 393, height: 590)

    @Test("작은 점프가 쉼 없이 이어지고 착지할 때만 몸이 눌린다")
    func bodyChangesAcrossHop() {
        let cycle = 0.62
        let landing = FlameHopMotion.sample(seed: 0, time: cycle * 0.04, size: field, reduceMotion: false)
        let airborne = FlameHopMotion.sample(seed: 0, time: cycle * 0.62, size: field, reduceMotion: false)
        let falling = FlameHopMotion.sample(seed: 0, time: cycle * 0.90, size: field, reduceMotion: false)

        #expect(landing.bodyScaleY < 1)
        #expect(airborne.bodyScaleY > 1)
        #expect(airborne.lift > 10)
        #expect(landing.dustOpacity > 0)
        #expect(falling.lift > 0)
        #expect(falling.dustOpacity == 0)
    }

    @Test("올라갈 때보다 빠르게 떨어져 바로 다음 걸음으로 이어진다")
    func descentIsQuickerThanAscent() {
        let cycle = 0.62
        let apex = FlameHopMotion.sample(seed: 0, time: cycle * 0.62, size: field, reduceMotion: false)
        let nearLanding = FlameHopMotion.sample(seed: 0, time: cycle * 0.94, size: field, reduceMotion: false)
        let nextHop = FlameHopMotion.sample(seed: 0, time: cycle * 1.12, size: field, reduceMotion: false)

        #expect(apex.lift > 10)
        #expect(nearLanding.lift < 3)
        #expect(nextHop.lift > 2)
    }

    @Test("짧은 걸음으로 계속 이동하고 화면 가장자리를 벗어나지 않는다")
    func hopsStayWithinField() {
        for seed in [0.0, 0.27, 0.61, 0.94] {
            for step in 0...100 {
                let time = Double(step) / 100 * (88 + seed * 10)
                let pose = FlameHopMotion.sample(seed: seed, time: time, size: field, reduceMotion: false)
                #expect(pose.groundPosition.x >= 44 && pose.groundPosition.x <= field.width - 44)
                #expect(pose.groundPosition.y >= 52 && pose.groundPosition.y <= field.height - 52)
            }
        }

        let start = FlameHopMotion.sample(seed: 0, time: 0, size: field, reduceMotion: false)
        let afterOneHop = FlameHopMotion.sample(seed: 0, time: 0.62, size: field, reduceMotion: false)
        let distance = hypot(
            afterOneHop.groundPosition.x - start.groundPosition.x,
            afterOneHop.groundPosition.y - start.groundPosition.y
        )
        #expect(distance > 2 && distance < 20)
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
}
