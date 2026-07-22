import Foundation
import Observation

enum Tab: Hashable {
    case home, history, progress, profile
}

@Observable
final class AppState {
    var tab: Tab = .home

    // Active workout flow
    var activeWorkout: Workout?
    var workoutPresented = false
    var showSummary = false
    var xpGained = 0
    var showStartSheet = false

    // Rest timer
    var restEndsAt: Date?
    var restTotal: Double = 0

    var restRemaining: Double {
        guard let end = restEndsAt else { return 0 }
        return max(0, end.timeIntervalSinceNow)
    }

    func startRest(seconds: Int) {
        guard seconds > 0 else { return }
        restTotal = Double(seconds)
        restEndsAt = Date().addingTimeInterval(restTotal)
    }

    func addRest(_ seconds: Double = 30) {
        guard let end = restEndsAt else { return }
        restEndsAt = end.addingTimeInterval(seconds)
        restTotal += seconds
    }

    func stopRest() {
        restEndsAt = nil
        restTotal = 0
    }

    func endWorkoutFlow() {
        workoutPresented = false
        activeWorkout = nil
        showSummary = false
        xpGained = 0
        stopRest()
    }
}
