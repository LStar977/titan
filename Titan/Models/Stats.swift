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

    static func volume(_ w: Workout) -> Double {
        w.entries
            .flatMap { $0.sets }
            .filter { $0.isCompleted }
            .reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    static func completedSetCount(_ w: Workout) -> Int {
        w.entries.flatMap { $0.sets }.filter { $0.isCompleted }.count
    }

    static func prSets(_ w: Workout) -> [(name: String, set: SetEntry)] {
        w.sortedEntries.flatMap { entry in
            entry.completedSets.filter { $0.isPR }.map { (entry.displayName, $0) }
        }
    }

    /// Best e1RM ever recorded for an exercise across completed non-warm-up sets,
    /// excluding one specific set (the one just logged).
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

    /// Best single-set weight for an exercise (with reps), for "BEST SET" stats.
    static func bestSet(exerciseName: String, workouts: [Workout]) -> (weight: Double, reps: Int)? {
        var best: (weight: Double, reps: Int)?
        for w in workouts {
            for entry in w.entries where entry.displayName == exerciseName {
                for s in entry.sets where s.isCompleted && s.type != .warmup && s.weight > 0 {
                    if best == nil || s.weight > best!.weight || (s.weight == best!.weight && s.reps > best!.reps) {
                        best = (s.weight, s.reps)
                    }
                }
            }
        }
        return best
    }

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

    /// Total completed volume attributed to each muscle. Primary muscle gets full
    /// credit, secondary muscles half.
    static func volumeByMuscle(_ workouts: [Workout]) -> [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for w in workouts {
            for entry in w.entries {
                guard let ex = entry.exercise else { continue }
                let vol = entry.sets
                    .filter { $0.isCompleted }
                    .reduce(0.0) { $0 + $1.weight * Double($1.reps) }
                guard vol > 0 else { continue }
                out[ex.muscle, default: 0] += vol
                for m in ex.secondary {
                    out[m, default: 0] += vol * 0.5
                }
            }
        }
        return out
    }

    /// Most recent completed sets for an exercise (used for ghost values).
    static func lastSets(exerciseName: String, workouts: [Workout], excluding: Workout? = nil) -> [SetEntry] {
        let sorted = workouts.sorted { $0.startedAt > $1.startedAt }
        for w in sorted {
            if let excluding, w === excluding { continue }
            guard w.endedAt != nil else { continue }
            for entry in w.sortedEntries where entry.displayName == exerciseName {
                let done = entry.completedSets.filter { $0.type != .warmup }
                if !done.isEmpty { return done }
            }
        }
        return []
    }
}

// MARK: - Titan Ranks

struct Rank {
    let index: Int // 0...11

    var groupIndex: Int { index / 3 }
    var tierNumeral: String { ["I", "II", "III"][index % 3] }
    var groupName: String { Rank.groupNames[groupIndex] }
    var title: String { "\(groupName) \(tierNumeral)" }

    static let groupNames = ["BRONZE", "IRON", "SPARTAN", "TITAN"]
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
}
