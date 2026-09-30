import CoreGraphics
import Foundation

struct FlameMotionParticipant: Equatable, Identifiable {
    let id: UUID
    let kind: FlameMotionKind
    var createdAt: TimeInterval? = nil
}

/// Each character owns its random journey and rest schedule, independently of all other flames.
struct FlameFieldMotion {
    private struct Character {
        let seed: Double
        var kind: FlameMotionKind
        var position: CGPoint
        var facing: CGFloat = 1
        var restingSince: TimeInterval
        var nextMoveAt: TimeInterval
        var runIndex = 0
        var run: FlameHopRun?
    }

    private var characters: [UUID: Character] = [:]
    private var pausedAt: TimeInterval?
    private var advancedThrough: TimeInterval?
    private var hasLoadedPopulation = false

    var nextEventAt: TimeInterval? {
        guard pausedAt == nil else { return nil }
        return characters.values.map { $0.run?.endsAt ?? $0.nextMoveAt }.min()
            .map { max($0, advancedThrough ?? $0) }
    }

    mutating func updateParticipants(_ participants: [FlameMotionParticipant], at time: TimeInterval, size: CGSize) {
        let clock = pausedAt ?? time
        if pausedAt == nil { advance(to: clock, size: size) }
        let ids = Set(participants.map(\.id))
        characters = characters.filter { ids.contains($0.key) }
        for participant in participants.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            if var existing = characters[participant.id] {
                if existing.kind != participant.kind {
                    existing.position = existing.run?.position(at: clock) ?? existing.position
                    existing.facing = existing.run?.facing ?? existing.facing
                    existing.kind = participant.kind
                    existing.run = nil
                    existing.restingSince = clock
                    existing.nextMoveAt = clock + restDuration(for: existing)
                    characters[participant.id] = existing
                }
            } else {
                let seed = FlameHopMotion.seed(for: participant.id)
                let position = initialPosition(seed: seed, at: clock, size: size)
                let age = participant.createdAt.map { time - $0 }
                let isFresh = age.map { $0 >= 0 && $0 <= 5 } == true
                // Existing records start at different times; a newly saved/added flame moves immediately.
                let shouldMoveImmediately = hasLoadedPopulation || isFresh
                characters[participant.id] = Character(
                    seed: seed, kind: participant.kind, position: position, restingSince: clock,
                    nextMoveAt: clock + 0.25 + 3.75 * FlameHopMotion.random(seed: seed, index: 0, channel: 10),
                    run: shouldMoveImmediately ? FlameHopMotion.makeRun(
                        seed: seed, kind: participant.kind, index: 0, at: clock, from: position, size: size
                    ) : nil
                )
            }
        }
        advancedThrough = clock
        hasLoadedPopulation = true
    }

    mutating func advance(to time: TimeInterval, size: CGSize) {
        guard pausedAt == nil else { return }
        // Ordered event times make the schedule independent of the rendering frame rate.
        while let eventTime = nextEventAt, eventTime <= time {
            for id in Array(characters.keys) {
                guard var character = characters[id] else { continue }
                if let run = character.run, run.endsAt <= eventTime {
                    character.position = run.to
                    character.facing = run.facing
                    character.run = nil
                    character.restingSince = run.endsAt
                    character.nextMoveAt = run.endsAt + restDuration(for: character)
                    character.runIndex += 1
                }
                if character.run == nil && character.nextMoveAt <= eventTime {
                    character.run = FlameHopMotion.makeRun(
                        seed: character.seed, kind: character.kind, index: character.runIndex,
                        at: eventTime, from: character.position, size: size
                    )
                }
                characters[id] = character
            }
        }
        advancedThrough = time
    }

    func pose(for id: UUID, at time: TimeInterval, size: CGSize, reduceMotion: Bool) -> FlameHopPose? {
        guard let character = characters[id] else { return nil }
        return FlameHopMotion.sample(
            run: character.run, time: pausedAt ?? time, size: size,
            restingAt: character.position, restingSince: character.restingSince,
            facing: character.facing, seed: character.seed, kind: character.kind, reduceMotion: reduceMotion
        )
    }

    mutating func pause(at time: TimeInterval) {
        guard pausedAt == nil else { return }
        pausedAt = time
    }

    mutating func resume(at time: TimeInterval) {
        guard let pausedAt else { return }
        let offset = max(0, time - pausedAt)
        if let advancedThrough { self.advancedThrough = advancedThrough + offset }
        for id in Array(characters.keys) {
            guard var character = characters[id] else { continue }
            character.restingSince += offset
            character.nextMoveAt += offset
            if var run = character.run {
                run.startedAt += offset
                character.run = run
            }
            characters[id] = character
        }
        self.pausedAt = nil
    }

    private func restDuration(for character: Character) -> TimeInterval {
        FlameMotionProfile.forKind(character.kind).pauseDuration
            * (0.45 + 1.55 * FlameHopMotion.random(seed: character.seed, index: character.runIndex, channel: 11))
    }

    private func initialPosition(seed: Double, at time: TimeInterval, size: CGSize) -> CGPoint {
        var best = FlameHopMotion.initialPosition(seed: seed)
        var bestDistance: CGFloat = -1
        // Spread new flames without moving any character that is already on screen.
        for attempt in 0..<12 {
            let candidate = attempt == 0 ? best : CGPoint(
                x: 0.08 + 0.84 * FlameHopMotion.random(seed: seed, index: attempt, channel: 7),
                y: 0.08 + 0.84 * FlameHopMotion.random(seed: seed, index: attempt, channel: 8)
            )
            let point = FlameHopMotion.fieldPosition(candidate, size: size)
            let nearest = characters.values.map { character in
                let other = FlameHopMotion.fieldPosition(character.run?.position(at: time)
                                                        ?? character.position, size: size)
                return hypot(point.x - other.x, point.y - other.y)
            }.min() ?? .greatestFiniteMagnitude
            if nearest > bestDistance { best = candidate; bestDistance = nearest }
            if nearest >= 76 { return candidate }
        }
        return best
    }
}
