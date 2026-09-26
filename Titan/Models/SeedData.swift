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
        ("Sit-Up", .bodyweight, .core, []),
        // Cardio (logged in minutes)
        ("Treadmill Run", .machine, .cardio, []),
        ("Incline Treadmill Walk", .machine, .cardio, []),
        ("Stationary Bike", .machine, .cardio, []),
        ("Stair Climber", .machine, .cardio, []),
        ("Rowing Machine", .machine, .cardio, []),
        ("Elliptical", .machine, .cardio, []),
        ("Assault Bike", .machine, .cardio, []),
        ("Jump Rope", .bodyweight, .cardio, []),
        ("Sled Push", .other, .cardio, []),
        ("Outdoor Run", .bodyweight, .cardio, []),
        // Stretching & warm-up (logged in minutes)
        ("Hamstring Stretch", .bodyweight, .mobility, []),
        ("Quad Stretch", .bodyweight, .mobility, []),
        ("Hip Flexor Stretch", .bodyweight, .mobility, []),
        ("Couch Stretch", .bodyweight, .mobility, []),
        ("Shoulder Stretch", .bodyweight, .mobility, []),
        ("Chest Doorway Stretch", .bodyweight, .mobility, []),
        ("Cat-Cow", .bodyweight, .mobility, []),
        ("Downward Dog", .bodyweight, .mobility, []),
        ("Child's Pose", .bodyweight, .mobility, []),
        ("Arm Circles", .bodyweight, .mobility, []),
        ("Leg Swings", .bodyweight, .mobility, []),
        ("World's Greatest Stretch", .bodyweight, .mobility, []),
        ("Foam Rolling", .other, .mobility, [])
    ]

}

// MARK: - Building live workouts

enum WorkoutBuilder {
    /// Title given to a workout built from scratch until it's renamed or
    /// auto-named from what was trained.
    static let defaultTitle = "My Workout"

    /// Create a workout (optionally from a routine), pre-filling each set with
    /// ghost values from the athlete's last session of that exercise.
    /// `history` must be newest first.
    static func start(routine: Routine?, context: ModelContext, history: [Workout]) -> Workout {
        let workout = Workout(title: routine?.name ?? defaultTitle)
        // Custom workouts open in setup mode — the clock waits for START.
        workout.hasBegun = routine != nil
        context.insert(workout)

        if let routine {
            for (index, item) in routine.sortedItems.enumerated() {
                let entry = WorkoutEntry(
                    orderIndex: index,
                    exercise: item.exercise,
                    restSeconds: item.restSeconds,
                    supersetGroup: item.supersetGroup
                )
                entry.exerciseName = item.displayName
                entry.targetLow = item.repLow
                entry.targetHigh = item.repHigh
                context.insert(entry)
                workout.entries.append(entry)

                let prev = Stats.lastSets(exerciseName: entry.displayName, workouts: history)
                let bump = progressionBump(prev: prev, plannedSets: item.plannedSets, repHigh: item.repHigh, exercise: item.exercise)
                for i in 0..<max(1, item.plannedSets) {
                    let prevSet = i < prev.count ? prev[i] : prev.last
                    var weight = prevSet?.weight ?? 0
                    var reps = prevSet?.reps ?? item.repLow
                    if bump > 0 && weight > 0 {
                        weight += bump
                        reps = item.repLow
                    }
                    let set = SetEntry(orderIndex: i, weight: weight, reps: reps, type: .working)
                    context.insert(set)
                    entry.sets.append(set)
                }
            }
        }
        // Save now so new objects get permanent IDs before anyone starts typing.
        try? context.save()
        return workout
    }

    /// Double progression: when every working set last time reached the top of
    /// the rep range, add one increment and start back at the bottom of it.
    static func progressionBump(prev: [SetEntry], plannedSets: Int, repHigh: Int, exercise: Exercise?) -> Double {
        guard Prefs.shared.autoProgress, repHigh > 0, !prev.isEmpty else { return 0 }
        guard let exercise, !exercise.muscle.isDuration else { return 0 }
        guard prev.count >= plannedSets else { return 0 }
        guard prev.allSatisfy({ $0.weight > 0 && $0.reps >= repHigh }) else { return 0 }
        let unit = Prefs.shared.unit
        return unit.toLb(unit.step)
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
        let fallbackReps = exercise.muscle.isDuration ? 10 : 8
        let count = max(exercise.muscle.isDuration ? 1 : 3, prev.count)
        for i in 0..<count {
            let prevSet = i < prev.count ? prev[i] : prev.last
            let set = SetEntry(orderIndex: i, weight: prevSet?.weight ?? 0, reps: prevSet?.reps ?? fallbackReps, type: .working)
            context.insert(set)
            entry.sets.append(set)
        }
        try? context.save()
    }

    /// A fresh copy of a past workout — same exercises and set counts, with
    /// numbers from the most recent session of each. Starts immediately.
    static func repeatWorkout(_ source: Workout, context: ModelContext, history: [Workout]) -> Workout {
        let workout = Workout(title: source.title)
        workout.hasBegun = true
        context.insert(workout)

        for (index, old) in source.sortedEntries.enumerated() {
            let entry = WorkoutEntry(
                orderIndex: index,
                exercise: old.exercise,
                restSeconds: old.restSeconds,
                supersetGroup: old.supersetGroup
            )
            entry.exerciseName = old.displayName
            entry.targetLow = old.targetLow
            entry.targetHigh = old.targetHigh
            context.insert(entry)
            workout.entries.append(entry)

            let prev = Stats.lastSets(exerciseName: entry.displayName, workouts: history, excluding: workout)
            let count = max(1, old.workingSets.count)
            for i in 0..<count {
                let prevSet = i < prev.count ? prev[i] : prev.last
                let set = SetEntry(
                    orderIndex: i,
                    weight: prevSet?.weight ?? 0,
                    reps: prevSet?.reps ?? (old.targetLow > 0 ? old.targetLow : 8),
                    type: .working
                )
                context.insert(set)
                entry.sets.append(set)
            }
        }
        try? context.save()
        return workout
    }

    /// Turns a finished workout into a reusable routine.
    @discardableResult
    static func saveAsRoutine(_ workout: Workout, context: ModelContext, routines: [Routine]) -> Routine {
        let taken = Set(routines.map { $0.name })
        var name = workout.title
        var n = 2
        while taken.contains(name) {
            name = "\(workout.title) \(n)"
            n += 1
        }
        let routine = Routine(name: name, orderIndex: (routines.map { $0.orderIndex }.max() ?? -1) + 1)
        context.insert(routine)
        for (i, entry) in workout.sortedEntries.enumerated() {
            let working = entry.workingSets
            let reps = working.map { $0.reps }
            let low = entry.targetLow > 0 ? entry.targetLow : (reps.min() ?? 8)
            let high = entry.targetHigh > 0 ? entry.targetHigh : (reps.max() ?? 12)
            let item = RoutineItem(
                orderIndex: i,
                exercise: entry.exercise,
                plannedSets: max(1, working.count),
                repLow: min(low, high),
                repHigh: max(low, high),
                restSeconds: entry.restSeconds,
                supersetGroup: entry.supersetGroup
            )
            if item.exercise == nil { item.exerciseName = entry.displayName }
            context.insert(item)
            routine.items.append(item)
        }
        try? context.save()
        return routine
    }

    /// Drops sets that were never logged and exercises left empty, then
    /// renumbers what remains. Run when a workout is finished.
    static func cleanUp(_ workout: Workout, context: ModelContext) {
        for entry in workout.entries {
            let pending = entry.sets.filter { !$0.isCompleted }
            for s in pending {
                entry.sets.removeAll { $0 === s }
                context.delete(s)
            }
        }
        let empty = workout.entries.filter { $0.sets.isEmpty }
        for e in empty {
            workout.entries.removeAll { $0 === e }
            context.delete(e)
        }
        for (i, e) in workout.sortedEntries.enumerated() {
            e.orderIndex = i
        }
    }

    /// Closes out a workout that was left running (app killed, phone died):
    /// keeps what was logged, or deletes it when nothing was.
    static func closeStale(_ workout: Workout, context: ModelContext) {
        let done = workout.entries.flatMap { $0.sets }.filter { $0.isCompleted }
        guard !done.isEmpty else {
            context.delete(workout)
            return
        }
        cleanUp(workout, context: context)
        if workout.title == defaultTitle {
            workout.title = Stats.autoTitle(workout)
        }
        let last = done.compactMap { $0.completedAt }.max()
        workout.endedAt = last ?? workout.startedAt.addingTimeInterval(3600)
        workout.hasBegun = true
    }
}
