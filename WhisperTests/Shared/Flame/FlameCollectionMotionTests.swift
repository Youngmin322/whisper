import CoreGraphics
import Testing
@testable import Whisper

@Suite("병에 담기 순서와 입구 통과")
struct FlameCollectionMotionTests {
    @Test("모든 불꽃이 통과할 동안 마개가 열려 있고, 닫힌 다음 전환한다", arguments: [1, 3, 10, 100])
    func corkClearsEveryFlame(count: Int) {
        let motion = FlameCollectionMotion(count: count)
        #expect(motion.duration < 2.5)
        #expect(motion.corkOpenness(at: 0) == 0)
        for tick in 0...300 {
            let time = Double(tick) / 120
            for index in 0..<count {
                let progress = motion.flightProgress(at: time, index: index)
                if progress > 0 && progress < 1 {
                    #expect(motion.corkOpenness(at: time) > 0.999)
                }
            }
        }
        #expect(motion.flightProgress(at: motion.closingStartsAt, index: count - 1) == 1)
        #expect(motion.corkOpenness(at: motion.duration) == 0)
        #expect(abs(motion.corkSettle(at: motion.duration)) < 0.001)
    }

    @Test("불꽃은 원래 위치에서 출발해 병 입구를 통과하고 병 안에 남는다", arguments: [
        CGSize(width: 320, height: 300), CGSize(width: 393, height: 590), CGSize(width: 900, height: 900)
    ])
    func passesThroughNeck(size: CGSize) {
        let motion = FlameCollectionMotion(count: 1)
        let jar = FlameCollectionJarLayout(size: size)
        for origin in [CGPoint(x: 48, y: 56), CGPoint(x: size.width - 48, y: size.height - 56)] {
            let initial = motion.flight(at: 0, index: 0, from: origin, jar: jar)
            #expect(initial.position == origin)
            #expect(initial.scaleX == 1 && initial.scaleY == 1)

            let arrival = FlameCollectionMotion.flightStart
                + FlameCollectionMotion.flightDuration * Double(FlameCollectionMotion.mouthProgress)
            let entering = motion.flight(at: arrival, index: 0, from: origin, jar: jar)
            #expect(abs(entering.position.x - jar.mouth.x) < 0.001)
            #expect(abs(entering.position.y - jar.mouth.y) < 0.001)
            #expect(48 * entering.scaleX < jar.mouthWidth)
            #expect(entering.opacity == 1)

            let stored = motion.flight(at: motion.duration, index: 0, from: origin, jar: jar)
            #expect(stored.position == jar.restingPoint(index: 0))
            #expect(stored.position.y > jar.mouth.y)
            #expect(stored.position.y + 48 * stored.scaleY / 2 < jar.center.y + jar.height / 2)
            #expect(stored.opacity == 1)
        }
    }

    @Test("불꽃이 많아도 순서대로 출발하며 입구 밖에서 사라지지 않는다")
    func staggerAndFadeInside() {
        let motion = FlameCollectionMotion(count: 10)
        let jar = FlameCollectionJarLayout(size: CGSize(width: 393, height: 590))
        let origin = CGPoint(x: 80, y: 100)
        let time = FlameCollectionMotion.flightStart + 0.1
        #expect(motion.flightProgress(at: time, index: 0) > 0)
        #expect(motion.flightProgress(at: time, index: 9) == 0)
        for tick in 0...250 {
            let time = Double(tick) / 100
            for index in 0..<10 {
                let pose = motion.flight(at: time, index: index, from: origin, jar: jar)
                if pose.opacity < 1 {
                    #expect(pose.position.y >= jar.mouth.y)
                }
                #expect(pose.position.x.isFinite && pose.position.y.isFinite)
            }
        }
    }
}
