import CoreGraphics
import Foundation
import Testing
@testable import Whisper

@Suite("개별 불꽃의 이동과 긴 휴식")
struct FlameFieldMotionTests {
    private let field = CGSize(width: 393, height: 590)

    @Test("1·3·6·10개 모두 각자의 랜덤 휴식 뒤 연속적으로 이동한다", arguments: [1, 3, 6, 10])
    func randomRestAndContinuousMovement(count: Int) throws {
        let participants = makeParticipants(count: count)
        var motion = FlameFieldMotion()
        motion.updateParticipants(participants, at: 0, size: field)
        var movingTicks: [UUID: Int] = [:]
        var moveCounts: [UUID: Int] = [:]
        var previous: [UUID: FlameHopPose] = [:]
        var lastLanding: [UUID: Double] = [:]
        var starts: [UUID: Double] = [:]

        for tick in 0...2400 {
            let time = Double(tick) * 0.05
            motion.advance(to: time, size: field)
            for participant in participants {
                let pose = try #require(motion.pose(for: participant.id, at: time, size: field, reduceMotion: false))
                if pose.isMoving {
                    movingTicks[participant.id, default: 0] += 1
                    if previous[participant.id]?.isMoving != true {
                        moveCounts[participant.id, default: 0] += 1
                        starts[participant.id] = time
                        if let landing = lastLanding[participant.id] {
                            #expect(time - landing >= FlameMotionProfile.forKind(participant.kind).pauseDuration * 0.45 - 0.05)
                        }
                    }
                } else if previous[participant.id]?.isMoving == true {
                    lastLanding[participant.id] = time
                    let maximumDuration = FlameMotionProfile.forKind(participant.kind).stepDuration
                        * Double(FlameMotionProfile.forKind(participant.kind).stepsPerBurst) * 1.083
                    #expect(time - (starts[participant.id] ?? time) <= maximumDuration + 0.05)
                }
                if let previousPose = previous[participant.id] {
                    let distance = hypot(pose.groundPosition.x - previousPose.groundPosition.x,
                                         pose.groundPosition.y - previousPose.groundPosition.y)
                    #expect(distance < 8)
                    if !pose.isMoving && !previousPose.isMoving {
                        #expect(pose.groundPosition == previousPose.groundPosition)
                    }
                }
                #expect(pose.groundPosition.x >= 48 && pose.groundPosition.x <= field.width - 48)
                #expect(pose.groundPosition.y >= 56 && pose.groundPosition.y <= field.height - 56)
                previous[participant.id] = pose
            }
        }
        for participant in participants {
            #expect(Double(movingTicks[participant.id, default: 0]) / 2401 < 0.25)
            #expect(moveCounts[participant.id, default: 0] >= 3)
        }
    }

    @Test("다른 불꽃의 수와 동작은 자신의 이동 시작 시점과 걸음 박자에 영향을 주지 않는다")
    func schedulesAreIndependent() throws {
        let participants = makeParticipants(count: 10)
        let first = try #require(participants.first)
        var alone = FlameFieldMotion()
        var together = FlameFieldMotion()
        alone.updateParticipants([first], at: 0, size: field)
        together.updateParticipants(participants, at: 0, size: field)
        for tick in 0...2400 {
            let time = Double(tick) * 0.05
            alone.advance(to: time, size: field)
            together.advance(to: time, size: field)
            let soloPose = try #require(alone.pose(for: first.id, at: time, size: field, reduceMotion: false))
            let groupPose = try #require(together.pose(for: first.id, at: time, size: field, reduceMotion: false))
            #expect(soloPose.isMoving == groupPose.isMoving)
            #expect(soloPose.lift == groupPose.lift)
            // Company may change where a flame heads, never its timing or bounce.
            #expect(soloPose.body.stretch == groupPose.body.stretch)
        }
    }

    @Test("떨어져 있던 불꽃은 서로에게 다가가 곁에 머물되 겹치지 않는다")
    func flamesKeepEachOtherCompany() throws {
        let participants = makeParticipants(count: 3, sameKind: .joy)
        var motion = FlameFieldMotion()
        motion.updateParticipants(participants, at: 0, size: field)
        func nearestGap(at time: Double) throws -> CGFloat {
            let points = try participants.map {
                try #require(motion.pose(for: $0.id, at: time, size: field, reduceMotion: false)).groundPosition
            }
            var gap = CGFloat.greatestFiniteMagnitude
            for a in points.indices {
                for b in points.indices where a < b {
                    gap = min(gap, hypot(points[a].x - points[b].x, points[a].y - points[b].y))
                }
            }
            return gap
        }
        let initial = try nearestGap(at: 0)
        var closest = initial
        var restingClosest = CGFloat.greatestFiniteMagnitude
        for tick in 0...2400 {
            let time = Double(tick) * 0.05
            motion.advance(to: time, size: field)
            let gap = try nearestGap(at: time)
            closest = min(closest, gap)
            let anyMoving = try participants.contains {
                try #require(motion.pose(for: $0.id, at: time, size: field, reduceMotion: false)).isMoving
            }
            if !anyMoving { restingClosest = min(restingClosest, gap) }
        }
        #expect(initial > 76)
        #expect(closest < FlameFieldMotion.companionDistance + 14)
        #expect(restingClosest > 30)
    }

    @Test("곁에 온 불꽃이 있으면 쉬던 불꽃이 그쪽으로 돌아본다")
    func restingFlameTurnsToVisitor() throws {
        let participants = makeParticipants(count: 4, sameKind: .calm)
        var motion = FlameFieldMotion()
        motion.updateParticipants(participants, at: 0, size: field)
        var previous: [UUID: FlameHopPose] = [:]
        var restTurns = 0
        for tick in 0...4800 {
            let time = Double(tick) * 0.05
            motion.advance(to: time, size: field)
            for participant in participants {
                let pose = try #require(motion.pose(for: participant.id, at: time, size: field, reduceMotion: false))
                if let earlier = previous[participant.id], !pose.isMoving, !earlier.isMoving,
                   pose.facing != earlier.facing {
                    restTurns += 1
                    #expect(pose.groundPosition == earlier.groundPosition)
                }
                previous[participant.id] = pose
            }
        }
        #expect(restTurns > 0)
    }

    @Test("빈 곳을 누르면 모든 불꽃이 그 주위로 모인 뒤 각자의 박자로 돌아간다", arguments: [1, 3, 6, 10])
    func touchGathersFlames(count: Int) throws {
        let participants = makeParticipants(count: count, sameKind: .joy)
        var motion = FlameFieldMotion()
        motion.updateParticipants(participants, at: 0, size: field)
        motion.advance(to: 2, size: field)
        let point = CGPoint(x: 200, y: 300)
        motion.gather(at: point, time: 2, size: field)
        var previous: [UUID: CGPoint] = [:]
        var arrived = Set<UUID>()
        let reach = max(40, CGFloat(count) * 9) + 8
        for tick in 0...300 {
            let time = 2 + Double(tick) * 0.05
            motion.advance(to: time, size: field)
            for participant in participants {
                let pose = try #require(motion.pose(for: participant.id, at: time, size: field, reduceMotion: false))
                if let earlier = previous[participant.id] {
                    #expect(hypot(pose.groundPosition.x - earlier.x, pose.groundPosition.y - earlier.y) < 12)
                }
                #expect(pose.groundPosition.x >= 48 && pose.groundPosition.x <= field.width - 48)
                #expect(pose.groundPosition.y >= 56 && pose.groundPosition.y <= field.height - 56)
                previous[participant.id] = pose.groundPosition
                if hypot(pose.groundPosition.x - point.x, pose.groundPosition.y - point.y) <= reach {
                    arrived.insert(participant.id)
                }
            }
        }
        #expect(arrived.count == count)
        var moved = false
        for tick in 0...1200 where !moved {
            let time = 17 + Double(tick) * 0.05
            motion.advance(to: time, size: field)
            moved = try participants.contains {
                try #require(motion.pose(for: $0.id, at: time, size: field, reduceMotion: false)).isMoving
            }
        }
        #expect(moved)
    }

    @Test("멈춘 동안에는 누르기에 반응하지 않는다")
    func pausedFieldIgnoresTouch() throws {
        let participants = makeParticipants(count: 3, sameKind: .joy)
        var touched = FlameFieldMotion()
        var untouched = FlameFieldMotion()
        for index in 0..<2 {
            var motion = FlameFieldMotion()
            motion.updateParticipants(participants, at: 0, size: field)
            motion.pause(at: 1)
            if index == 0 { motion.gather(at: CGPoint(x: 200, y: 300), time: 1, size: field) }
            motion.resume(at: 1)
            if index == 0 { touched = motion } else { untouched = motion }
        }
        for tick in 0...200 {
            let time = 1 + Double(tick) * 0.05
            touched.advance(to: time, size: field)
            untouched.advance(to: time, size: field)
            for participant in participants {
                let a = try #require(touched.pose(for: participant.id, at: time, size: field, reduceMotion: false))
                let b = try #require(untouched.pose(for: participant.id, at: time, size: field, reduceMotion: false))
                #expect(a.groundPosition == b.groundPosition && a.isMoving == b.isMoving)
            }
        }
    }

    private func makeParticipants(count: Int, sameKind: FlameMotionKind? = nil) -> [FlameMotionParticipant] {
        (0..<count).map { index in
            FlameMotionParticipant(
                id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(index + 1))),
                kind: sameKind ?? FlameMotionKind.allCases[index % FlameMotionKind.allCases.count]
            )
        }
    }
}
