import Foundation
import SwiftData

enum SeedData {
    static func seedIfNeeded(_ context: ModelContext) {
        let supCount = (try? context.fetchCount(FetchDescriptor<Supplement>())) ?? 0
        if supCount == 0 {
            context.insert(Supplement(name: "Creatine", serving: 5, unit: "g", orderIndex: 0))
            context.insert(Supplement(name: "Whey Protein", serving: 25, unit: "g", orderIndex: 1))
        }

        removeLegacySeedRoutines(context)

        // Sync the built-in library: insert any exercise not already present,
        // so updates that add exercises reach existing installs too.
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var names = Set(existing.map { $0.name })
        for spec in library where !names.contains(spec.0) {
            let ex = Exercise(name: spec.0, equipment: spec.1, muscle: spec.2, secondary: spec.3)
            context.insert(ex)
            names.insert(spec.0)
        }

        let profCount = (try? context.fetchCount(FetchDescriptor<Profile>())) ?? 0
        if profCount == 0 {
            context.insert(Profile())
        }

        try? context.save()
    }

    /// Early builds seeded four starter routines into the user's own list; the
    /// routine list now belongs to the user (programs live in the library instead).
    private static func removeLegacySeedRoutines(_ context: ModelContext) {
        let flag = "titan.removedSeedRoutines.v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        let legacyNames: Set<String> = ["Push Day A", "Pull Day A", "Leg Day", "Push Day B"]
        if let routines = try? context.fetch(FetchDescriptor<Routine>()) {
            for routine in routines where legacyNames.contains(routine.name) {
                context.delete(routine)
            }
        }
        UserDefaults.standard.set(true, forKey: flag)
    }

    // (name, equipment, primary, secondary)
    private static let library: [(String, Equipment, Muscle, [Muscle])] = [
        // Chest
        ("Bench Press", .barbell, .chest, [.triceps, .shoulders]),
        ("Incline Bench Press", .barbell, .chest, [.shoulders]),
        ("Close-Grip Bench Press", .barbell, .chest, [.triceps]),
        ("Dumbbell Bench Press", .dumbbell, .chest, [.triceps]),
        ("Incline DB Press", .dumbbell, .chest, [.shoulders]),
        ("Cable Fly", .cable, .chest, []),
        ("Dumbbell Fly", .dumbbell, .chest, []),
        ("Incline Dumbbell Fly", .dumbbell, .chest, []),
        ("Pec Deck", .machine, .chest, []),
        ("Machine Chest Press", .machine, .chest, [.triceps]),
        ("Chest Dip", .bodyweight, .chest, [.triceps]),
        ("Push-Up", .bodyweight, .chest, [.triceps, .core]),
        // Back
        ("Deadlift", .barbell, .back, [.hamstrings, .glutes]),
        ("Barbell Row", .barbell, .back, [.biceps]),
        ("Pull-Up", .bodyweight, .back, [.biceps]),
        ("Weighted Pull-Up", .bodyweight, .back, [.biceps]),
        ("Chin-Up", .bodyweight, .back, [.biceps]),
        ("Lat Pulldown", .cable, .back, [.biceps]),
        ("Seated Cable Row", .cable, .back, [.biceps]),
        ("T-Bar Row", .machine, .back, [.biceps]),
        ("Single-Arm DB Row", .dumbbell, .back, [.biceps]),
        ("Rack Pull", .barbell, .back, [.traps, .glutes]),
        ("Barbell Shrug", .barbell, .traps, []),
        ("Face Pull", .cable, .shoulders, [.traps]),
        // Shoulders
        ("Overhead Press", .barbell, .shoulders, [.triceps]),
        ("DB Shoulder Press", .dumbbell, .shoulders, [.triceps]),
        ("Arnold Press", .dumbbell, .shoulders, [.triceps]),
        ("Lateral Raise", .dumbbell, .shoulders, []),
        ("Cable Lateral Raise", .cable, .shoulders, []),
        ("Front Raise", .dumbbell, .shoulders, []),
        ("Rear Delt Fly", .dumbbell, .shoulders, [.back]),
        ("Machine Shoulder Press", .machine, .shoulders, [.triceps]),
        ("Upright Row", .barbell, .shoulders, [.traps]),
        // Arms
        ("Barbell Curl", .barbell, .biceps, [.forearms]),
        ("Dumbbell Curl", .dumbbell, .biceps, []),
        ("Hammer Curl", .dumbbell, .biceps, [.forearms]),
        ("Preacher Curl", .machine, .biceps, []),
        ("Cable Curl", .cable, .biceps, []),
        ("Triceps Pushdown", .cable, .triceps, []),
        ("Overhead Triceps Extension", .dumbbell, .triceps, []),
        ("Skull Crusher", .barbell, .triceps, []),
        ("Triceps Dip", .bodyweight, .triceps, [.chest]),
        ("Wrist Curl", .dumbbell, .forearms, []),
        // Legs
        ("Back Squat", .barbell, .quads, [.glutes, .core]),
        ("Front Squat", .barbell, .quads, [.core]),
        ("Goblet Squat", .dumbbell, .quads, [.glutes]),
        ("Leg Press", .machine, .quads, [.glutes]),
        ("Bulgarian Split Squat", .dumbbell, .quads, [.glutes]),
        ("Walking Lunge", .dumbbell, .quads, [.glutes]),
        ("Leg Extension", .machine, .quads, []),
        ("Romanian Deadlift", .barbell, .hamstrings, [.glutes]),
        ("Leg Curl", .machine, .hamstrings, []),
        ("Hip Thrust", .barbell, .glutes, [.hamstrings]),
        ("Glute Kickback", .cable, .glutes, []),
        ("Standing Calf Raise", .machine, .calves, []),
        ("Seated Calf Raise", .machine, .calves, []),
        // Core
        ("Plank", .bodyweight, .core, []),
        ("Hanging Leg Raise", .bodyweight, .core, []),
        ("Cable Crunch", .cable, .core, []),
        ("Ab Wheel Rollout", .bodyweight, .core, []),
        ("Russian Twist", .dumbbell, .core, []),
        ("Sit-Up", .bodyweight, .core, [])
    ]

}

// MARK: - Building live workouts

enum WorkoutBuilder {
    /// Create a workout (optionally from a routine), pre-filling each set with
    /// ghost values from the athlete's last session of that exercise.
    static func start(routine: Routine?, context: ModelContext, history: [Workout]) -> Workout {
        let workout = Workout(title: routine?.name ?? "My Workout")
        // Custom workouts open in setup mode — the clock waits for START.
        workout.hasBegun = routine != nil
        context.insert(workout)

        if let routine {
            for item in routine.sortedItems {
                let entry = WorkoutEntry(
                    orderIndex: item.orderIndex,
                    exercise: item.exercise,
                    restSeconds: item.restSeconds,
                    supersetGroup: item.supersetGroup
                )
                context.insert(entry)
                workout.entries.append(entry)

                let prev = Stats.lastSets(exerciseName: entry.displayName, workouts: history)
                for i in 0..<max(1, item.plannedSets) {
                    let prevSet = i < prev.count ? prev[i] : prev.last
                    let set = SetEntry(
                        orderIndex: i,
                        weight: prevSet?.weight ?? 0,
                        reps: prevSet?.reps ?? item.repLow,
                        type: .working
                    )
                    context.insert(set)
                    entry.sets.append(set)
                }
            }
        }
        return workout
    }

    static func addExercise(_ exercise: Exercise, to workout: Workout, context: ModelContext, history: [Workout], defaultRest: Int) {
        let entry = WorkoutEntry(
            orderIndex: (workout.entries.map { $0.orderIndex }.max() ?? -1) + 1,
            exercise: exercise,
            restSeconds: defaultRest
        )
        context.insert(entry)
        workout.entries.append(entry)

        let prev = Stats.lastSets(exerciseName: exercise.name, workouts: history, excluding: workout)
        let count = max(3, prev.count)
        for i in 0..<count {
            let prevSet = i < prev.count ? prev[i] : prev.last
            let set = SetEntry(orderIndex: i, weight: prevSet?.weight ?? 0, reps: prevSet?.reps ?? 8, type: .working)
            context.insert(set)
            entry.sets.append(set)
        }
    }
}
