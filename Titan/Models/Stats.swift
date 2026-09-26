import Foundation
import SwiftData

// MARK: - Training math

enum Stats {
    /// Epley estimated one-rep max.
    static func e1RM(_ weight: Double, _ reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    /// Effective volume of one set: added weight plus (for bodyweight
    /// exercises) the athlete's bodyweight snapshotted at completion.
    static func setVolume(_ s: SetEntry) -> Double {
        (s.weight + s.bodyLoad) * Double(s.reps)
    }

    static func volume(_ w: Workout) -> Double {
        w.entries
            .flatMap { $0.sets }
            .filter { $0.isCompleted }
            .reduce(0) { $0 + setVolume($1) }
    }

    static func completedSetCount(_ w: Workout) -> Int {
        w.entries.flatMap { $0.sets }.filter { $0.isCompleted }.count
    }

    static func totalSetCount(_ w: Workout) -> Int {
        w.entries.reduce(0) { $0 + $1.sets.count }
    }

    static func prSets(_ w: Workout) -> [(name: String, set: SetEntry)] {
        w.sortedEntries.flatMap { entry in
            entry.completedSets.filter { $0.isPR }.map { (entry.displayName, $0) }
        }
    }

    /// Best e1RM ever recorded for an exercise across completed non-warm-up sets,
    /// excluding one specific set.
    static func bestE1RM(exerciseName: String, workouts: [Workout], excluding: SetEntry? = nil) -> Double {
        var best: Double = 0
        for w in workouts {
            for entry in w.entries where entry.displayName == exerciseName {
                for s in entry.sets where s.isCompleted && s.type != .warmup {
                    if let excluding, s === excluding { continue }
                    best = max(best, e1RM(s.weight, s.reps))
                }
            }
        }
        return best
    }

    /// Heaviest single working set for an exercise (ties broken by reps).
    static func bestSet(exerciseName: String, workouts: [Workout]) -> (weight: Double, reps: Int)? {
        var best: (weight: Double, reps: Int)?
        for w in workouts {
            for entry in w.entries where entry.displayName == exerciseName {
                for s in entry.sets where s.isCompleted && s.type != .warmup && s.weight > 0 {
                    if let b = best {
                        if s.weight > b.weight || (s.weight == b.weight && s.reps > b.reps) {
                            best = (s.weight, s.reps)
                        }
                    } else {
                        best = (s.weight, s.reps)
                    }
                }
            }
        }
        return best
    }

    /// Best set per exercise name in one pass — for lists that badge every row.
    static func bestSetIndex(_ workouts: [Workout]) -> [String: (weight: Double, reps: Int)] {
        var out: [String: (weight: Double, reps: Int)] = [:]
        for w in workouts where w.endedAt != nil {
            for entry in w.entries {
                for s in entry.sets where s.isCompleted && s.type != .warmup && s.weight > 0 {
                    if let b = out[entry.displayName] {
                        if s.weight > b.weight || (s.weight == b.weight && s.reps > b.reps) {
                            out[entry.displayName] = (s.weight, s.reps)
                        }
                    } else {
                        out[entry.displayName] = (s.weight, s.reps)
                    }
                }
            }
        }
        return out
    }

    // MARK: Personal records

    /// The best an exercise has been done, kept on two scales so bodyweight
    /// moves compare like with like: added-weight sets by e1RM, unweighted
    /// sets by reps.
    struct PRBest {
        var load: Double = 0
        var reps: Int = 0

        mutating func absorb(_ s: SetEntry) {
            guard s.isCompleted, s.type != .warmup, s.reps > 0 else { return }
            if s.weight > 0 {
                load = max(load, Stats.e1RM(s.weight, s.reps))
            } else {
                reps = max(reps, s.reps)
            }
        }
    }

    /// Re-derives the PR flags for one workout against everything finished
    /// before it, in one pass over history — cheap enough to run on every
    /// logged set.
    static func recomputePRs(in workout: Workout, all: [Workout]) {
        let names = Set(workout.entries.map { $0.displayName })
        var history: [String: PRBest] = [:]
        for w in all where w !== workout && w.endedAt != nil && w.startedAt < workout.startedAt {
            for e in w.entries {
                let name = e.displayName
                guard names.contains(name) else { continue }
                for s in e.sets { history[name, default: PRBest()].absorb(s) }
            }
        }
        flagPRs(in: workout, history: history)
    }

    /// Re-derives PR flags for every workout from `date` onward in a single
    /// chronological pass — needed after history is edited or deleted, because
    /// later records are measured against it. A workout in progress is
    /// re-checked too, but never counts as history.
    static func recomputePRs(since date: Date, all: [Workout]) {
        var history: [String: PRBest] = [:]
        for w in all.sorted(by: { $0.startedAt < $1.startedAt }) {
            if w.startedAt >= date { flagPRs(in: w, history: history) }
            guard w.endedAt != nil else { continue }
            for e in w.entries {
                let name = e.displayName
                for s in e.sets { history[name, default: PRBest()].absorb(s) }
            }
        }
    }

    /// Flags at most one record per exercise — even one done twice in the
    /// session: a new best e1RM or, for bodyweight moves without added
    /// weight, a new most-reps. The first time on either scale is a
    /// baseline, not a record.
    private static func flagPRs(in workout: Workout, history: [String: PRBest]) {
        var groups: [(name: String, bodyweight: Bool, sets: [SetEntry])] = []
        for entry in workout.sortedEntries {
            guard !entry.isDuration else { continue }
            let name = entry.displayName
            if let i = groups.firstIndex(where: { $0.name == name }) {
                groups[i].sets += entry.sortedSets
            } else {
                groups.append((name: name, bodyweight: entry.exercise?.equipment == .bodyweight, sets: entry.sortedSets))
            }
        }

        var winners = Set<ObjectIdentifier>()
        for group in groups {
            guard let past = history[group.name] else { continue }
            let counted = group.sets.filter { $0.isCompleted && $0.type != .warmup && $0.reps > 0 }
            var winner: SetEntry?
            if past.load > 0 {
                var best = past.load
                for s in counted where s.weight > 0 {
                    let score = e1RM(s.weight, s.reps)
                    if score > best + 0.0001 {
                        best = score
                        winner = s
                    }
                }
            }
            if winner == nil, group.bodyweight, past.reps > 0 {
                var best = past.reps
                for s in counted where s.weight == 0 && s.reps > best {
                    best = s.reps
                    winner = s
                }
            }
            if let winner { winners.insert(ObjectIdentifier(winner)) }
        }

        // Write only flags that change, so a logged set doesn't redraw every row.
        for entry in workout.entries {
            for s in entry.sets {
                let flag = winners.contains(ObjectIdentifier(s))
                if s.isPR != flag { s.isPR = flag }
            }
        }
    }

    // MARK: Streaks & calendar

    /// Consecutive-day training streak ending today (or yesterday).
    static func streak(_ workouts: [Workout], now: Date = Date()) -> Int {
        let cal = Calendar.current
        let days = Set(workouts.map { cal.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = cal.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let y = cal.date(byAdding: .day, value: -1, to: cursor), days.contains(y) else { return 0 }
            cursor = y
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// Monday-start week interval containing `date`.
    static func weekInterval(containing date: Date) -> DateInterval {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return DateInterval(start: start, duration: 7 * 86400)
    }

    static func workouts(_ workouts: [Workout], in interval: DateInterval) -> [Workout] {
        workouts.filter { interval.contains($0.startedAt) }
    }

    /// Volume per week for the last `count` weeks, oldest first.
    static func weeklyVolumes(_ finished: [Workout], count: Int, now: Date = Date()) -> [(start: Date, volume: Double)] {
        var out: [(start: Date, volume: Double)] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            guard let ref = Calendar.current.date(byAdding: .day, value: -7 * i, to: now) else { continue }
            let week = weekInterval(containing: ref)
            let vol = workouts(finished, in: week).reduce(0.0) { $0 + volume($1) }
            out.append((week.start, vol))
        }
        return out
    }

    // MARK: Muscles

    /// Total completed volume attributed to each muscle. Primary muscle gets full
    /// credit, secondary muscles half.
    static func volumeByMuscle(_ workouts: [Workout]) -> [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for w in workouts {
            for entry in w.entries {
                guard let ex = entry.exercise else { continue }
                let vol = entry.sets
                    .filter { $0.isCompleted }
                    .reduce(0.0) { $0 + setVolume($1) }
                guard vol > 0 else { continue }
                out[ex.muscle, default: 0] += vol
                for m in ex.secondary {
                    out[m, default: 0] += vol * 0.5
                }
            }
        }
        return out
    }

    /// Working sets per muscle — the number most programs are written in.
    /// Primary muscle counts a full set, secondary muscles half.
    static func setsByMuscle(_ workouts: [Workout]) -> [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for w in workouts {
            for entry in w.entries {
                guard let ex = entry.exercise, !ex.muscle.isDuration else { continue }
                let n = Double(entry.workingSets.count)
                guard n > 0 else { continue }
                out[ex.muscle, default: 0] += n
                for m in ex.secondary {
                    out[m, default: 0] += n * 0.5
                }
            }
        }
        return out
    }

    // MARK: History lookups

    /// Most recent completed working sets for an exercise (used for ghost values).
    /// `workouts` must be newest first.
    static func lastSets(exerciseName: String, workouts: [Workout], excluding: Workout? = nil) -> [SetEntry] {
        lastEntry(exerciseName: exerciseName, workouts: workouts, excluding: excluding)?.workingSets ?? []
    }

    /// The most recent finished entry for an exercise that has working sets.
    /// `workouts` must be newest first.
    static func lastEntry(exerciseName: String, workouts: [Workout], excluding: Workout? = nil) -> WorkoutEntry? {
        for w in workouts {
            if let excluding, w === excluding { continue }
            guard w.endedAt != nil else { continue }
            for entry in w.sortedEntries where entry.displayName == exerciseName {
                if !entry.workingSets.isEmpty { return entry }
            }
        }
        return nil
    }

    /// The best weight lifted for at least N reps, for each N in `targets`.
    static func repMaxes(exerciseName: String, workouts: [Workout], targets: [Int] = [1, 3, 5, 8, 10, 12]) -> [RepMax] {
        var best: [Int: RepMax] = [:]
        for w in workouts where w.endedAt != nil {
            for entry in w.entries where entry.displayName == exerciseName {
                for s in entry.sets where s.isCompleted && s.type != .warmup && s.weight > 0 {
                    for t in targets where s.reps >= t {
                        if s.weight > (best[t]?.weight ?? 0) {
                            best[t] = RepMax(reps: t, weight: s.weight, actualReps: s.reps, date: w.startedAt)
                        }
                    }
                }
            }
        }
        return targets.compactMap { best[$0] }
    }

    // MARK: Workout naming

    /// A readable name from what was trained: "Chest & Triceps" style.
    static func autoTitle(_ w: Workout) -> String {
        var counts: [String: Int] = [:]
        for entry in w.entries {
            guard let m = entry.exercise?.muscle else { continue }
            let n = entry.isDuration ? entry.completedSets.count : entry.workingSets.count
            guard n > 0 else { continue }
            counts[m.groupName, default: 0] += n
        }
        let lifting = counts.filter { $0.key != "Cardio" && $0.key != "Mobility" }
        if lifting.isEmpty {
            let other = counts.keys.sorted()
            return other.isEmpty ? "Workout" : other.joined(separator: " & ")
        }
        let groups = lifting.sorted { a, b in
            a.value == b.value ? a.key < b.key : a.value > b.value
        }.map { $0.key }

        switch groups.count {
        case 1:
            switch groups[0] {
            case "Legs": return "Leg Day"
            case "Core": return "Core"
            default: return "\(groups[0]) Day"
            }
        case 2:
            return "\(groups[0]) & \(groups[1])"
        case 3:
            return groups.contains("Legs") ? "Full Body" : "Upper Body"
        default:
            return "Full Body"
        }
    }

    // MARK: Warm-ups

    /// A standard ramp to the first working weight, rounded to loadable jumps.
    static func warmupRamp(workingLb: Double, barbell: Bool) -> [WarmupStep] {
        let unit = Prefs.shared.unit
        let working = unit.fromLb(workingLb)
        let step = unit.step
        let bar = unit.barWeight
        guard working > 0 else { return [] }

        var out: [WarmupStep] = []
        if barbell && working > bar * 2 {
            out.append(WarmupStep(lb: unit.toLb(bar), reps: 10))
        }
        let ramp: [(pct: Double, reps: Int)] = [(0.5, 8), (0.7, 5), (0.85, 3)]
        for r in ramp {
            var load = (working * r.pct / step).rounded() * step
            if barbell { load = max(load, bar) }
            guard load < working - 0.01, load > 0 else { continue }
            if let last = out.last, abs(unit.fromLb(last.lb) - load) < 0.01 { continue }
            out.append(WarmupStep(lb: unit.toLb(load), reps: r.reps))
        }
        return out
    }
}

struct RepMax: Identifiable {
    let reps: Int
    let weight: Double
    let actualReps: Int
    let date: Date
    var id: Int { reps }
}

struct WarmupStep {
    let lb: Double
    let reps: Int
}

// MARK: - Titan Ranks

struct Rank: Equatable {
    let index: Int // 0...11

    var groupIndex: Int { index / 3 }
    var tierNumeral: String { ["I", "II", "III"][index % 3] }
    var groupName: String { Rank.groupNames[groupIndex] }
    var title: String { "\(groupName) \(tierNumeral)" }

    static let groupNames = Brand.rankNames
}

enum RankSystem {
    /// XP required to *enter* each of the 12 ranks (Bronze I ... Titan III).
    static let thresholds = [0, 300, 800, 1600, 2800, 4400, 6400, 9000, 12200, 16000, 20500, 26000]

    static func rank(xp: Int) -> Rank {
        var idx = 0
        for (i, t) in thresholds.enumerated() where xp >= t { idx = i }
        return Rank(index: idx)
    }

    /// Progress within the current rank. `next` is nil at the top rank.
    static func progress(xp: Int) -> (rank: Rank, fraction: Double, current: Int, span: Int, next: Rank?) {
        let r = rank(xp: xp)
        let base = thresholds[r.index]
        if r.index >= thresholds.count - 1 {
            return (r, 1.0, xp - base, 1, nil)
        }
        let span = thresholds[r.index + 1] - base
        let cur = xp - base
        return (r, min(1.0, Double(cur) / Double(span)), cur, span, Rank(index: r.index + 1))
    }

    static func xp(for workout: Workout) -> Int {
        var xp = 50 // completing a workout
        for entry in workout.entries {
            for s in entry.sets where s.isCompleted {
                xp += s.type == .warmup ? 5 : 15
                if s.isPR { xp += 75 }
            }
        }
        return xp
    }

    /// Lifetime XP, derived from the log itself — so editing or deleting a
    /// workout keeps the rank honest.
    static func totalXP(_ workouts: [Workout]) -> Int {
        workouts.filter { $0.endedAt != nil }.reduce(0) { $0 + xp(for: $1) }
    }
}
