import CoreGraphics
import Foundation

struct FlameMotionParticipant: Equatable, Identifiable {
    let id: UUID
    let kind: FlameMotionKind
    var createdAt: TimeInterval? = nil
}

/// Each character keeps its own rest schedule and tempo. Only where it goes is social:
/// it may walk over to another flame, and everyone answers a touch on the field.
struct FlameFieldMotion {
    /// Side-by-side spacing for two flames keeping each other company.
    static let companionDistance: CGFloat = 46
    static let restTurnDuration: TimeInterval = 0.22

    private struct Gathering {
        let spot: CGPoint
        let focus: CGPoint
        var expiresAt: TimeInterval
    }

    private struct Character {
        let seed: Double
        var kind: FlameMotionKind
        var position: CGPoint
        var facing: CGFloat = 1
        var restingSince: TimeInterval
        var nextMoveAt: TimeInterval
        var runIndex = 0
        var run: FlameHopRun?
        var visiting: UUID?
        var gathering: Gathering?
        var turnedFrom: CGFloat = 1
        var turnedAt: TimeInterval?
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
            // One snapshot per event keeps every decision independent of iteration order.
            let places = places(at: eventTime, size: size)
            for id in sortedIDs {
                guard var character = characters[id] else { continue }
                var greeting: (friend: UUID, from: CGFloat)?
                if let run = character.run, run.endsAt <= eventTime {
                    let here = FlameHopMotion.fieldPosition(run.to, size: size)
                    character.position = run.to
                    character.facing = run.facing
                    character.run = nil
                    character.restingSince = run.endsAt
                    character.nextMoveAt = run.endsAt + restDuration(for: character)
                    if let gathering = character.gathering {
                        let spot = FlameHopMotion.fieldPosition(gathering.spot, size: size)
                        if hypot(spot.x - here.x, spot.y - here.y) < 6 || run.endsAt >= gathering.expiresAt {
                            character.gathering = nil
                            let focus = FlameHopMotion.fieldPosition(gathering.focus, size: size)
                            turn(&character, toward: focus.x, from: here.x, at: run.endsAt)
                        } else {
                            character.nextMoveAt = run.endsAt + 0.2 + 0.3
                                * FlameHopMotion.random(seed: character.seed, index: character.runIndex, channel: 19)
                        }
                    } else if let friend = character.visiting, let there = places[friend],
                              hypot(there.x - here.x, there.y - here.y) < 80 {
                        turn(&character, toward: there.x, from: here.x, at: run.endsAt)
                        greeting = (friend, here.x)
                    }
                    character.visiting = nil
                    character.runIndex += 1
                }
                if character.run == nil && character.nextMoveAt <= eventTime {
                    startRun(&character, id: id, at: eventTime, places: places, size: size)
                }
                characters[id] = character
                // A resting flame looks at whoever just came over.
                if let greeting, var friend = characters[greeting.friend], friend.run == nil,
                   let there = places[greeting.friend] {
                    turn(&friend, toward: greeting.from, from: there.x, at: eventTime)
                    characters[greeting.friend] = friend
                }
            }
        }
        advancedThrough = time
    }

    /// Everyone hurries to a ring around the touched point, then goes back to its own rhythm.
    mutating func gather(at point: CGPoint, time: TimeInterval, size: CGSize) {
        guard pausedAt == nil, !characters.isEmpty else { return }
        advance(to: time, size: size)
        let places = places(at: time, size: size)
        // Slots follow the flames' current bearings so their paths do not cross.
        let order = sortedIDs.map { id -> (id: UUID, bearing: Double) in
            let place = places[id] ?? point
            return (id, atan2(Double(place.y - point.y), Double(place.x - point.x)))
        }.sorted { $0.bearing < $1.bearing }
        let radius: CGFloat = order.count == 1 ? 0 : max(40, CGFloat(order.count) * 9)
        let focus = FlameHopMotion.normalizedPosition(point, size: size)
        for (slot, entry) in order.enumerated() {
            guard var character = characters[entry.id] else { continue }
            let bearing = order[0].bearing + 2 * Double.pi * Double(slot) / Double(order.count)
            let spot = CGPoint(x: point.x + radius * CGFloat(cos(bearing)),
                               y: point.y + radius * 0.6 * CGFloat(sin(bearing)))
            character.gathering = Gathering(spot: FlameHopMotion.normalizedPosition(spot, size: size),
                                            focus: focus, expiresAt: time + 12)
            character.visiting = nil
            if character.run == nil {
                character.nextMoveAt = time + 0.05 + 0.3
                    * FlameHopMotion.random(seed: character.seed, index: character.runIndex, channel: 19)
            }
            characters[entry.id] = character
        }
        advancedThrough = time
    }

    func pose(for id: UUID, at time: TimeInterval, size: CGSize, reduceMotion: Bool) -> FlameHopPose? {
        guard let character = characters[id] else { return nil }
        let clock = pausedAt ?? time
        var pose = FlameHopMotion.sample(
            run: character.run, time: clock, size: size,
            restingAt: character.position, restingSince: character.restingSince,
            facing: character.facing, seed: character.seed, kind: character.kind, reduceMotion: reduceMotion
        )
        if !reduceMotion, !pose.isMoving, let turnedAt = character.turnedAt {
            let progress = (clock - turnedAt) / Self.restTurnDuration
            if progress < 1 {
                pose.facingScale = character.turnedFrom + (character.facing - character.turnedFrom)
                    * CGFloat(FlameHopMotion.smoothstep(progress))
            }
        }
        return pose
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
            character.turnedAt = character.turnedAt.map { $0 + offset }
            character.gathering?.expiresAt += offset
            if var run = character.run {
                run.startedAt += offset
                character.run = run
            }
            characters[id] = character
        }
        self.pausedAt = nil
    }

    private var sortedIDs: [UUID] { characters.keys.sorted { $0.uuidString < $1.uuidString } }

    private func places(at time: TimeInterval, size: CGSize) -> [UUID: CGPoint] {
        characters.mapValues { character in
            let position = character.run.map { $0.endsAt <= time ? $0.to : $0.position(at: time) }
                ?? character.position
            return FlameHopMotion.fieldPosition(position, size: size)
        }
    }

    /// Only mirrored artwork can look the other way; joy keeps its approved pose.
    private func turn(_ character: inout Character, toward x: CGFloat, from own: CGFloat, at time: TimeInterval) {
        guard character.kind.mirrorsArtwork, abs(x - own) > 1 else { return }
        let facing: CGFloat = x < own ? -1 : 1
        guard facing != character.facing else { return }
        character.turnedFrom = character.facing
        character.turnedAt = time
        character.facing = facing
    }

    private func startRun(_ character: inout Character, id: UUID, at time: TimeInterval,
                          places: [UUID: CGPoint], size: CGSize) {
        if let gathering = character.gathering {
            character.run = FlameHopMotion.makeRun(
                seed: character.seed, kind: character.kind, index: character.runIndex,
                at: time, from: character.position, size: size,
                toward: FlameHopMotion.fieldPosition(gathering.spot, size: size), eager: true
            )
            return
        }
        let here = places[id] ?? FlameHopMotion.fieldPosition(character.position, size: size)
        let others = sortedIDs.filter { $0 != id }.compactMap { other in places[other].map { (id: other, place: $0) } }
        func chance(_ channel: UInt64) -> Double {
            FlameHopMotion.random(seed: character.seed, index: character.runIndex, channel: channel)
        }
        func distance(_ place: CGPoint) -> CGFloat { hypot(place.x - here.x, place.y - here.y) }

        var destination: CGPoint?
        let apart = others.filter { distance($0.place) > Self.companionDistance + 14 }
        if !apart.isEmpty, chance(16) < sociability(character.kind) {
            let nearest = apart.min { distance($0.place) < distance($1.place) }
            let friend = chance(17) < 0.7 ? nearest : apart[min(apart.count - 1, Int(chance(18) * Double(apart.count)))]
            if let friend {
                // Stand beside the friend, on the side this flame is already coming from.
                var side: CGFloat = here.x >= friend.place.x ? 1 : -1
                let edge = FlameHopMotion.fieldPosition(CGPoint(x: side > 0 ? 1 : 0, y: 0), size: size).x
                if (friend.place.x + side * Self.companionDistance - edge) * side > 0 { side = -side }
                destination = CGPoint(x: friend.place.x + side * Self.companionDistance, y: friend.place.y)
                character.visiting = friend.id
            }
        }
        character.run = FlameHopMotion.makeRun(
            seed: character.seed, kind: character.kind, index: character.runIndex,
            at: time, from: character.position, size: size,
            toward: destination, avoiding: others.map(\.place)
        )
    }

    private func sociability(_ kind: FlameMotionKind) -> Double {
        switch kind {
        case .joy: 0.7
        case .calm: 0.5
        case .anxiety: 0.6
        case .sadness: 0.45
        case .anger: 0.3
        case .depression: 0.25
        }
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
