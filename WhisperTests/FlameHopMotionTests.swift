import CoreGraphics
import Testing
@testable import Whisper

@Suite("불꽃의 느린 도약")
struct FlameHopMotionTests {
    private let field = CGSize(width: 393, height: 590)

    @Test("웅크림과 도약, 착지가 서로 다른 몸 모양을 만든다")
    func bodyChangesAcrossHop() {
        let crouch = FlameHopMotion.sample(seed: 0, time: 2.7 * 0.12, size: field, reduceMotion: false)
        let airborne = FlameHopMotion.sample(seed: 0, time: 2.7 * 0.36, size: field, reduceMotion: false)
        let landing = FlameHopMotion.sample(seed: 0, time: 2.7 * 0.60, size: field, reduceMotion: false)
        let resting = FlameHopMotion.sample(seed: 0, time: 2.7 * 0.85, size: field, reduceMotion: false)

        #expect(crouch.bodyScaleY < 1)
        #expect(airborne.bodyScaleY > 1)
        #expect(airborne.lift > 20)
        #expect(landing.bodyScaleY < 1)
        #expect(landing.dustOpacity > 0)
        #expect(resting.lift == 0)
        #expect(resting.dustOpacity == 0)
    }

    @Test("정점 이후 빠르게 떨어지며 착지한다")
    func descentIsQuickerThanAscent() {
        let apex = FlameHopMotion.sample(seed: 0, time: 2.7 * 0.36, size: field, reduceMotion: false)
        let nearLanding = FlameHopMotion.sample(seed: 0, time: 2.7 * 0.51, size: field, reduceMotion: false)
        let landed = FlameHopMotion.sample(seed: 0, time: 2.7 * 0.54, size: field, reduceMotion: false)

        #expect(apex.lift > 24)
        #expect(nearLanding.lift < 8)
        #expect(landed.lift == 0)
        #expect(landed.dustOpacity > 0)
    }

    @Test("한 번에 짧게 이동하고 화면 가장자리를 벗어나지 않는다")
    func hopsStayWithinField() {
        for seed in [0.0, 0.27, 0.61, 0.94] {
            for step in 0..<FlameHopMotion.waypointCount {
                let cycle = 2.7 + seed * 0.6
                let time = (Double(step) - seed * 31 + 0.99) * cycle
                let pose = FlameHopMotion.sample(seed: seed, time: time, size: field, reduceMotion: false)
                #expect(pose.groundPosition.x >= 44 && pose.groundPosition.x <= field.width - 44)
                #expect(pose.groundPosition.y >= 52 && pose.groundPosition.y <= field.height - 52)
            }
        }

        let start = FlameHopMotion.sample(seed: 0, time: 0, size: field, reduceMotion: false)
        let afterOneHop = FlameHopMotion.sample(seed: 0, time: 2.7, size: field, reduceMotion: false)
        let distance = hypot(
            afterOneHop.groundPosition.x - start.groundPosition.x,
            afterOneHop.groundPosition.y - start.groundPosition.y
        )
        #expect(distance < 65)
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
