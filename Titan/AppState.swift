import Foundation
import Observation

enum Tab: Hashable {
    case home, history, progress, profile
}

/// What comes after the current rest — shown in the rest dock and the alert.
struct RestNext: Equatable {
    let title: String
    let detail: String
}

/// XP bookkeeping for the finish screen.
struct WorkoutSummary {
    let xpGained: Int
    let xpBefore: Int
    let xpAfter: Int

    var rankBefore: Rank { RankSystem.rank(xp: xpBefore) }
    var rankAfter: Rank { RankSystem.rank(xp: xpAfter) }
    var rankedUp: Bool { rankAfter.index > rankBefore.index }
}

@Observable
final class AppState {
    var tab: Tab = .home

    // Active workout flow
    var activeWorkout: Workout?
    var workoutPresented = false
    var showSummary = false
    var summary: WorkoutSummary?
    var showStartSheet = false

    // Rest timer
    var restEndsAt: Date?
    var restStartedAt: Date?
    var restTotal: Double = 0
    var restNext: RestNext?

    var restRemaining: Double {
        guard let end = restEndsAt else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    func startRest(seconds: Int, next: RestNext?) {
        guard seconds > 0 else { return }
        let now = Date()
        restTotal = Double(seconds)
        restStartedAt = now
        restEndsAt = now.addingTimeInterval(restTotal)
        restNext = next
        scheduleAlert()
    }

    /// Adds (or with a negative value, removes) rest time.
    func addRest(_ seconds: Double) {
        guard let end = restEndsAt else { return }
        let earliest = Date().addingTimeInterval(3)
        let newEnd = max(earliest, end.addingTimeInterval(seconds))
        restTotal = max(3, restTotal + newEnd.timeIntervalSince(end))
        restEndsAt = newEnd
        scheduleAlert()
    }

    /// The athlete skipped or the workout ended — cancel the pending alert too.
    func stopRest() {
        clearRest()
        RestAlerts.cancel()
    }

    /// The timer ran out on its own; the alert has already fired.
    func restFinished() {
        clearRest()
    }

    func endWorkoutFlow() {
        workoutPresented = false
        activeWorkout = nil
        showSummary = false
        summary = nil
        stopRest()
    }

    private func clearRest() {
        restEndsAt = nil
        restStartedAt = nil
        restTotal = 0
        restNext = nil
    }

    private func scheduleAlert() {
        guard let end = restEndsAt else { return }
        let body = restNext.map { "\($0.title) — \($0.detail)" } ?? "Rest is over."
        RestAlerts.schedule(at: end, title: Brand.restOverTitle, body: body)
    }
}
