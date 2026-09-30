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

    @Test("다른 불꽃의 수와 동작은 자신의 이동 시작 시점에 영향을 주지 않는다")
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
            #expect(soloPose.frameIndex == groupPose.frameIndex)
            #expect(soloPose.body == groupPose.body)
        }
    }

    @Test("새로 만든 첫 불꽃은 등장 직후 자신의 감정 동작을 시작한다", arguments: FlameMotionKind.allCases)
    func newlyCreatedFlameMovesImmediately(kind: FlameMotionKind) throws {
        var participant = try #require(makeParticipants(count: 1, sameKind: kind).first)
        participant.createdAt = 100
        var motion = FlameFieldMotion()
        motion.updateParticipants([participant], at: 100, size: field)
        let first = try #require(motion.pose(for: participant.id, at: 100, size: field, reduceMotion: false))
        let next = try #require(motion.pose(for: participant.id, at: 100.2, size: field, reduceMotion: false))
        #expect(first.isMoving && next.isMoving)
        #expect(next.frameIndex > 0)
        #expect(next.lift > 0 || next.body != .rest)
    }

    @Test("여러 새 불꽃도 기존 불꽃을 기다리지 않고 즉시 함께 움직일 수 있다")
    func newFlamesHaveNoConcurrencyLimit() throws {
        let participants = makeParticipants(count: 10, sameKind: .joy)
        var motion = FlameFieldMotion()
        motion.updateParticipants(Array(participants.prefix(1)), at: 0, size: field)
        motion.updateParticipants(participants, at: 1, size: field)
        let added = participants.dropFirst()
        let moving = added.filter {
            motion.pose(for: $0.id, at: 1.1, size: field, reduceMotion: false)?.isMoving == true
        }
        #expect(moving.count == added.count)
    }

    @Test("작성 화면에서 추가된 불꽃의 첫 동작은 홈으로 돌아올 때 이어진다")
    func newFlameWaitsForVisibleHome() throws {
        let participants = makeParticipants(count: 2, sameKind: .joy)
        var motion = FlameFieldMotion()
        motion.updateParticipants(Array(participants.prefix(1)), at: 0, size: field)
        motion.advance(to: 1, size: field)
        motion.pause(at: 1)
        motion.updateParticipants(participants, at: 30, size: field)
        motion.resume(at: 50)
        let id = participants[1].id
        let first = try #require(motion.pose(for: id, at: 50, size: field, reduceMotion: false))
        let next = try #require(motion.pose(for: id, at: 50.2, size: field, reduceMotion: false))
        #expect(first.isMoving && next.isMoving)
        #expect(first.groundPosition != next.groundPosition)
    }

    @Test("같은 감정의 불꽃들도 각자 다른 시점과 경로로 움직인다")
    func sameEmotionIsIndependent() throws {
        let participants = makeParticipants(count: 6, sameKind: .joy)
        var motion = FlameFieldMotion()
        motion.updateParticipants(participants, at: 0, size: field)
        var firstStart: [UUID: Double] = [:]
        var finalPoints: [CGPoint] = []
        for tick in 0...600 {
            let time = Double(tick) * 0.05
            motion.advance(to: time, size: field)
            for participant in participants {
                let pose = try #require(motion.pose(for: participant.id, at: time, size: field, reduceMotion: false))
                if pose.isMoving && firstStart[participant.id] == nil { firstStart[participant.id] = time }
            }
        }
        #expect(firstStart.count == participants.count)
        #expect(Set(firstStart.values).count >= 5)
        for participant in participants {
            finalPoints.append(try #require(motion.pose(for: participant.id, at: 30, size: field, reduceMotion: false)).groundPosition)
        }
        #expect(Set(finalPoints.map(\.x)).count == participants.count)
    }

    @Test("렌더링 빈도와 기록 순서가 달라도 같은 위치와 자세를 유지한다")
    func renderingDoesNotChangeJourneys() throws {
        let participants = makeParticipants(count: 10)
        var frequent = FlameFieldMotion()
        var sparse = FlameFieldMotion()
        frequent.updateParticipants(participants, at: 0, size: field)
        sparse.updateParticipants(participants.reversed(), at: 0, size: field)
        for tick in 0...900 { frequent.advance(to: Double(tick) / 30, size: field) }
        sparse.advance(to: 30, size: field)
        for participant in participants {
            let a = try #require(frequent.pose(for: participant.id, at: 30, size: field, reduceMotion: false))
            let b = try #require(sparse.pose(for: participant.id, at: 30, size: field, reduceMotion: false))
            #expect(a.groundPosition == b.groundPosition)
            #expect(a.frameIndex == b.frameIndex && a.facing == b.facing)
            #expect(a.body == b.body)
        }
        let id = participants[0].id
        let before = try #require(frequent.pose(for: id, at: 30, size: field, reduceMotion: false))
        frequent.updateParticipants(participants.reversed(), at: 30, size: field)
        let after = try #require(frequent.pose(for: id, at: 30, size: field, reduceMotion: false))
        #expect(before.groundPosition == after.groundPosition)
        #expect(before.frameIndex == after.frameIndex)
    }

    @Test("화면을 떠나거나 병에 담는 동안 멈추고 돌아오면 같은 위치에서 이어간다")
    func pauseAndResumeKeepPose() throws {
        let participants = makeParticipants(count: 3, sameKind: .joy)
        var motion = FlameFieldMotion()
        motion.updateParticipants(participants, at: 0, size: field)
        let time = try #require(motion.nextEventAt) + 0.2
        motion.advance(to: time, size: field)
        let id = try #require(participants.first {
            motion.pose(for: $0.id, at: time, size: field, reduceMotion: false)?.isMoving == true
        }).id
        let before = try #require(motion.pose(for: id, at: time, size: field, reduceMotion: false))
        motion.pause(at: time)
        motion.advance(to: 1000, size: field)
        let paused = try #require(motion.pose(for: id, at: 1000, size: field, reduceMotion: false))
        #expect(paused.groundPosition == before.groundPosition)
        #expect(paused.frameIndex == before.frameIndex && paused.lift == before.lift)
        #expect(motion.nextEventAt == nil)
        let reduced = try #require(motion.pose(for: id, at: 2000, size: field, reduceMotion: true))
        #expect(reduced.groundPosition == before.groundPosition)
        #expect(reduced.frameIndex == 0 && reduced.lift == 0 && reduced.dustOpacity == 0)
        #expect(reduced.body == .rest && !reduced.isMoving)
        motion.resume(at: 1000)
        let resumed = try #require(motion.pose(for: id, at: 1000, size: field, reduceMotion: false))
        #expect(hypot(resumed.groundPosition.x - before.groundPosition.x,
                      resumed.groundPosition.y - before.groundPosition.y) < 0.000001)
        #expect(resumed.frameIndex == before.frameIndex)
        motion.advance(to: 1000.1, size: field)
        let later = try #require(motion.pose(for: id, at: 1000.1, size: field, reduceMotion: false))
        #expect(later.groundPosition != resumed.groundPosition)
    }

    @Test("순간 추가·삭제와 감정 수정은 다른 불꽃의 위치를 바꾸지 않는다")
    func recordChangesPreserveExistingPositions() throws {
        let participants = makeParticipants(count: 3)
        var motion = FlameFieldMotion()
        motion.updateParticipants(participants, at: 0, size: field)
        motion.advance(to: 5, size: field)
        let before = try participants.map {
            try #require(motion.pose(for: $0.id, at: 5, size: field, reduceMotion: false)).groundPosition
        }
        let larger = makeParticipants(count: 6)
        motion.updateParticipants(larger, at: 5, size: field)
        for (index, participant) in participants.enumerated() {
            #expect(motion.pose(for: participant.id, at: 5, size: field, reduceMotion: false)?.groundPosition == before[index])
        }
        let changed = FlameMotionParticipant(id: participants[0].id, kind: .anger)
        motion.updateParticipants([changed, participants[1]], at: 5, size: field)
        #expect(motion.pose(for: changed.id, at: 5, size: field, reduceMotion: false)?.groundPosition == before[0])
        #expect(motion.pose(for: participants[1].id, at: 5, size: field, reduceMotion: false)?.groundPosition == before[1])
        #expect(motion.pose(for: participants[2].id, at: 5, size: field, reduceMotion: false) == nil)
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
