import CoreGraphics
import Testing
@testable import Whisper

@Suite("짧은 감정별 불꽃 걸음")
struct FlameHopMotionTests {
    private let field = CGSize(width: 393, height: 590)

    @Test("기쁨은 제자리에서 앞으로 웅크린 뒤 기울어 뛰고 착지 직전 몸을 세운다")
    func joyHopsForward() {
        let start = sample(time: 0)
        let crouch = sample(time: 0.10)
        let launch = sample(time: 0.14 + 0.32 * 0.2)
        let apex = sample(time: 0.14 + 0.16)
        let descending = sample(time: 0.14 + 0.32 * 0.9)
        #expect(crouch.groundPosition == start.groundPosition && crouch.lift == 0)
        #expect(crouch.body.stretch < 0 && crouch.body.rotation > 0)
        #expect(launch.body.stretch > 0 && launch.body.rotation > crouch.body.rotation && launch.lift > 0)
        #expect(abs(apex.lift - 11) < 0.000001 && abs(apex.body.stretch) < 0.000001)
        #expect(descending.body.rotation < 0 && descending.lift < apex.lift)
        #expect(launch.body.tipBend < 0)
        #expect(distance(start.groundPosition, descending.groundPosition) > 5)
    }

    @Test("기쁨은 휴식 중에 위치를 유지하며 작게 호흡한다")
    func restingPositionIsFixed() {
        let first = sample(time: 2)
        let later = sample(time: 5)
        #expect(first.groundPosition == later.groundPosition)
        #expect(!first.isMoving && !later.isMoving)
        #expect(first.lift == 0 && first.lead == 0)
        #expect(first.body != later.body)
        #expect(abs(first.body.tipBend) <= 0.012 && abs(later.body.tipBend) <= 0.012)
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
            #expect(distance(start, end) <= 60)
            #expect(distance(start, end) >= 20)
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
        #expect(run(.sadness).position(at: 0.2) == origin && run(.anger).position(at: 0.2).x > origin.x)
        #expect(run(.joy).position(at: 0.1) == origin)
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
        #expect(sample(time: 0.46 - 0.001).dustOpacity == 0)
        let landing = sample(time: 0.46 + 0.04)
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
            let mainMotion = pose(at: start + 0.30, activeRun: run)
            let settling = [0.62, 0.64, 0.655, 0.66 - 0.000001].map {
                pose(at: start + $0, activeRun: run)
            }
            #expect(mainMotion.lift > 0 && mainMotion.body.rotation * direction > 0)
            for (earlier, later) in zip(settling, settling.dropFirst()) {
                #expect(abs(earlier.body.rotation) >= abs(later.body.rotation))
                #expect(earlier.facing == later.facing)
            }
            #expect(abs(settling.last!.body.rotation) < 0.000001 && abs(settling.last!.body.stretch) < 0.000001)
        }
        let beforeLanding = pose(at: run.endsAt - 0.000001, activeRun: run)
        let landed = pose(at: run.endsAt, activeRun: run)
        let resting = pose(at: run.endsAt + 1, activeRun: nil)
        #expect(beforeLanding.facing == landed.facing && landed.facing == resting.facing)
        #expect(landed.body == .rest && resting.body != .rest)
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
        #expect(started.facingScale == 1)
        let turning = FlameHopMotion.sample(run: run, time: 10.05, size: field, restingAt: origin,
                                           restingSince: 0, facing: 1, seed: 0, kind: .joy, reduceMotion: false)
        let turned = FlameHopMotion.sample(run: run, time: 10.10, size: field, restingAt: origin,
                                          restingSince: 0, facing: 1, seed: 0, kind: .joy, reduceMotion: false)
        #expect(abs(turning.facingScale) < 0.000001)
        #expect(abs(turned.facingScale + 1) < 0.000001)
    }

    @Test("기쁨 동작은 웅크림·도약·착지·다음 걸음 경계에서 끊기지 않는다")
    func joyPhasesAreContinuous() {
        for boundary in [0.14, 0.46, 0.66, 0.66 + 0.14, 0.66 + 0.46] {
            let before = sample(time: boundary - 0.0000001)
            let after = sample(time: boundary + 0.0000001)
            #expect(abs(before.body.rotation - after.body.rotation) < 0.001)
            #expect(abs(before.body.stretch - after.body.stretch) < 0.001)
            #expect(abs(before.body.tipBend - after.body.tipBend) < 0.001)
            #expect(abs(before.lift - after.lift) < 0.001)
            #expect(distance(before.groundPosition, after.groundPosition) < 0.01)
        }
    }

    @Test("각 걸음은 착지에서 납작해졌다가 반동하고 앞으로 조금 미끄러진 뒤 원래 모양으로 멈춘다")
    func landingHasForwardCushion() {
        for step in 0..<2 {
            let contact = Double(step) * 0.66 + 0.46
            let touched = sample(time: contact)
            let compressed = sample(time: contact + 0.05)
            let rebound = sample(time: contact + 0.15)
            let settled = sample(time: contact + 0.20 - 0.000001)
            #expect(abs(compressed.lift) < 0.000001 && abs(rebound.lift) < 0.000001)
            #expect(compressed.body.stretch < -0.1 && compressed.body.rotation > 0)
            #expect(rebound.body.stretch > 0)
            #expect(abs(settled.body.stretch) < 0.001 && abs(settled.body.rotation) < 0.01)
            #expect(compressed.groundPosition.x > touched.groundPosition.x)
            #expect(settled.groundPosition.x > rebound.groundPosition.x)
        }
    }

    @Test("대기 깜빡임은 개체별 4~6초 간격이고 0.15초 뒤 눈을 다시 연다")
    func idleBlinksAreStableAndBounded() {
        for seed in [0.0, 0.27, 0.61] {
            var previous = 0.0
            for cycle in 0..<6 {
                let start = Double(cycle) * 5 + 4 + FlameHopMotion.random(seed: seed, index: cycle, channel: 15)
                if cycle > 0 { #expect(start - previous >= 4 && start - previous <= 6) }
                func idle(_ time: Double, reduced: Bool = false) -> FlameHopPose {
                    FlameHopMotion.sample(run: nil, time: time, size: field, restingAt: .zero,
                                          restingSince: 0, facing: -1, seed: seed, kind: .joy, reduceMotion: reduced)
                }
                #expect(idle(start).blinkScale == 1)
                #expect(abs(idle(start + 0.075).blinkScale - 0.08) < 0.000001)
                #expect(abs(idle(start + 0.15).blinkScale - 1) < 0.000001)
                let reduced = idle(start + 0.075, reduced: true)
                #expect(reduced.blinkScale == 1 && reduced.body == .rest && reduced.facingScale == -1)
                previous = start
            }
        }
    }

    @Test("깜빡임과 호흡 도중 출발해도 이전 대기 자세에서 이어진다", arguments: FlameMotionKind.allCases)
    func idleBlendsIntoTakeoff(kind: FlameMotionKind) {
        let seed = 0.27
        let start = 4 + FlameHopMotion.random(seed: seed, index: 0, channel: 15) + 0.075
        let origin = CGPoint(x: 0.5, y: 0.5)
        let run = FlameHopRun(kind: kind, startedAt: start, from: origin,
                              to: CGPoint(x: 0.4, y: 0.5), stepDuration: 0.66, steps: 1)
        func pose(run: FlameHopRun?, time: Double) -> FlameHopPose {
            FlameHopMotion.sample(run: run, time: time, size: field, restingAt: origin,
                                  restingSince: 0, facing: 1, seed: seed, kind: kind, reduceMotion: false)
        }
        let idle = pose(run: nil, time: start)
        let starting = pose(run: run, time: start)
        #expect(idle.body == starting.body)
        #expect(idle.blinkScale == starting.blinkScale && starting.blinkScale < 0.1)
        #expect(idle.facingScale == starting.facingScale)
        #expect(pose(run: run, time: start + 0.11).blinkScale == 1)
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
