import CoreGraphics
import Testing
@testable import Whisper

@Suite("짧은 감정별 불꽃 걸음")
struct FlameHopMotionTests {
    private let field = CGSize(width: 393, height: 590)

    @Test("기쁨의 기존 자세 프레임과 탄력은 유지한다")
    func referenceFramesAdvance() {
        let start = sample(time: 0)
        let bend = sample(time: 0.66 * 0.25)
        let launch = sample(time: 0.66 * 0.52)
        let landing = sample(time: 0.66 * 0.83)
        #expect(start.frameIndex == 0)
        #expect(bend.frameIndex == 4)
        #expect(launch.frameIndex == 8)
        #expect(landing.frameIndex == 13)
        #expect(launch.lead > bend.lead)
        #expect(launch.lift > 4)
        #expect(landing.lift < launch.lift)
        #expect(distance(start.groundPosition, landing.groundPosition) > 5)
    }

    @Test("기쁨은 휴식 중에 위치와 원본 형태를 그대로 유지한다")
    func restingPositionIsFixed() {
        let first = sample(time: 2)
        let later = sample(time: 5)
        #expect(first.groundPosition == later.groundPosition)
        #expect(!first.isMoving && !later.isMoving)
        #expect(first.frameIndex == 0 && first.lift == 0 && first.lead == 0)
        #expect(first.body == .rest && later.body == .rest)
    }

    @Test("개체와 이동 회차마다 방향·속도·거리·걸음 수가 독립적으로 달라진다")
    func individualJourneysVary() {
        let runs = [0.11, 0.27, 0.61, 0.94].flatMap { seed in
            (0..<4).map { index in
                FlameHopMotion.makeRun(seed: seed, kind: .joy, index: index, at: 0,
                                       from: CGPoint(x: 0.5, y: 0.5), size: field)
            }
        }
        #expect(Set(runs.map(\.stepDuration)).count == runs.count)
        #expect(Set(runs.map { $0.to.x }).count == runs.count)
        #expect(Set(runs.map(\.steps)) == [1, 2])
        for run in runs {
            let start = FlameHopMotion.fieldPosition(run.from, size: field)
            let end = FlameHopMotion.fieldPosition(run.to, size: field)
            #expect(distance(start, end) <= 30)
            #expect(distance(start, end) >= 10)
        }
        // Waiting is outside the run; it cannot speed up the journey.
        let repeated = FlameHopMotion.makeRun(seed: 0.11, kind: .joy, index: 0, at: 1000,
                                             from: CGPoint(x: 0.5, y: 0.5), size: field)
        #expect(repeated.stepDuration == runs[0].stepDuration)
        #expect(repeated.to == runs[0].to)
    }

    @Test("분노는 강하게 출발하고 불안은 먼저 멈칫한다")
    func emotionalTravelIsDistinct() {
        let origin = CGPoint(x: 0.3, y: 0.5)
        let target = CGPoint(x: 0.7, y: 0.5)
        func run(_ kind: FlameMotionKind) -> FlameHopRun {
            FlameHopRun(kind: kind, startedAt: 0, from: origin, to: target, stepDuration: 1, steps: 1)
        }
        #expect(run(.anger).position(at: 0.15).x > run(.joy).position(at: 0.15).x)
        #expect(run(.anxiety).position(at: 0.15) == origin)
        #expect(run(.sadness).position(at: 0.5).x < run(.joy).position(at: 0.5).x)
        for kind in FlameMotionKind.allCases {
            #expect(run(kind).position(at: 0) == origin)
            #expect(run(kind).position(at: 1) == target)
        }
    }

    @Test("짧은 이동은 작은 화면과 가장자리에서도 화면 안에 머문다")
    func staysInField() {
        for size in [field, CGSize(width: 180, height: 220), CGSize(width: 60, height: 80), .zero] {
            for kind in FlameMotionKind.allCases {
                for seed in [0.0, 0.27, 0.61, 0.94] {
                    for anchor in [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] {
                        let run = FlameHopMotion.makeRun(seed: seed, kind: kind, index: 0,
                                                        at: 0, from: anchor, size: size)
                        for tick in 0...20 {
                            let point = FlameHopMotion.fieldPosition(run.position(at: run.duration * Double(tick) / 20), size: size)
                            #expect(point.x >= 0 && point.x <= size.width)
                            #expect(point.y >= 0 && point.y <= size.height)
                        }
                    }
                }
            }
        }
    }

    @Test("먼지는 공중이 아닌 착지 구간에만 보인다")
    func dustFollowsLanding() {
        #expect(sample(time: 0.66 * 0.42).dustOpacity == 0)
        let landing = sample(time: 0.66 * 0.86)
        #expect(landing.dustOpacity > 0 && landing.dustOpacity < 0.24)
        #expect(sample(time: 2).dustOpacity == 0)
    }

    @Test("기쁨은 좌우 모두 착지 전에 원본 형태로 돌아가며 정지 경계에서 방향을 유지한다", arguments: [-1.0, 1.0])
    func joySettlesBeforeStopping(direction: Double) {
        let origin = CGPoint(x: 0.5, y: 0.5)
        let run = FlameHopRun(kind: .joy, startedAt: 10, from: origin,
                              to: CGPoint(x: 0.5 + direction * 0.1, y: 0.5), stepDuration: 0.66, steps: 2)
        func pose(at time: Double, activeRun: FlameHopRun?) -> FlameHopPose {
            FlameHopMotion.sample(run: activeRun, time: time, size: field, restingAt: run.to,
                                  restingSince: run.endsAt, facing: CGFloat(direction), seed: 0,
                                  kind: .joy, reduceMotion: false)
        }
        for step in 0..<run.steps {
            let start = run.startedAt + Double(step) * run.stepDuration
            let anticipation = pose(at: start, activeRun: run)
            let mainMotion = pose(at: start + run.stepDuration * 0.52, activeRun: run)
            let settling = [0.82, 0.90, 0.97, 0.999999].map {
                pose(at: start + run.stepDuration * $0, activeRun: run)
            }
            #expect(anticipation.referenceBlend == 0)
            #expect(mainMotion.referenceBlend == 1)
            for (earlier, later) in zip(settling, settling.dropFirst()) {
                #expect(earlier.referenceBlend > later.referenceBlend)
                #expect(earlier.facing == later.facing)
            }
            #expect(settling.last!.referenceBlend < 0.000001)
        }
        let beforeLanding = pose(at: run.endsAt - 0.000001, activeRun: run)
        let landed = pose(at: run.endsAt, activeRun: run)
        let resting = pose(at: run.endsAt + 1, activeRun: nil)
        #expect(beforeLanding.facing == landed.facing && landed.facing == resting.facing)
        #expect(landed.referenceBlend == 0 && resting.referenceBlend == 0)
        #expect(landed.body == .rest && resting.body == .rest)
        #expect(landed.groundPosition == resting.groundPosition)
    }

    @Test("새 이동 시작 전에는 이전 방향을 유지하고 실제 방향 변경 때만 돌아선다")
    func futureRunDoesNotTurnRestingFlame() {
        let origin = CGPoint(x: 0.5, y: 0.5)
        let run = FlameHopRun(kind: .joy, startedAt: 10, from: origin,
                              to: CGPoint(x: 0.4, y: 0.5), stepDuration: 0.66, steps: 1)
        let before = FlameHopMotion.sample(run: run, time: 9.9, size: field, restingAt: origin,
                                          restingSince: 0, facing: 1, seed: 0, kind: .joy, reduceMotion: false)
        let started = FlameHopMotion.sample(run: run, time: 10, size: field, restingAt: origin,
                                           restingSince: 0, facing: 1, seed: 0, kind: .joy, reduceMotion: false)
        #expect(!before.isMoving && before.facing == 1)
        #expect(started.isMoving && started.facing == -1)
    }

    private func sample(time: Double) -> FlameHopPose {
        let run = FlameHopRun(kind: .joy, startedAt: 0, from: CGPoint(x: 0.5, y: 0.5),
                              to: CGPoint(x: 0.58, y: 0.52), stepDuration: 0.66, steps: 2)
        return FlameHopMotion.sample(run: run, time: time, size: field, restingAt: run.from,
                                     restingSince: 0, facing: 1, seed: 0, kind: .joy, reduceMotion: false)
    }

    private func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(second.x - first.x, second.y - first.y)
    }
}
