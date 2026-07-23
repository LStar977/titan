import Foundation
import SwiftData

enum SeedData {
    static func seedIfNeeded(_ context: ModelContext) {
        let supCount = (try? context.fetchCount(FetchDescriptor<Supplement>())) ?? 0
        if supCount == 0 {
            context.insert(Supplement(name: "Creatine", serving: 5, unit: "g", orderIndex: 0))
            context.insert(Supplement(name: "Whey Protein", serving: 25, unit: "g", orderIndex: 1))
        }

        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else {
            try? context.save()
            return
        }

        var byName: [String: Exercise] = [:]
        for spec in library {
            let ex = Exercise(name: spec.0, equipment: spec.1, muscle: spec.2, secondary: spec.3)
            context.insert(ex)
            byName[spec.0] = ex
        }

        context.insert(Profile())

        for (idx, plan) in starterRoutines.enumerated() {
            let routine = Routine(name: plan.name, orderIndex: idx)
            context.insert(routine)
            for (i, item) in plan.items.enumerated() {
                let ri = RoutineItem(
                    orderIndex: i,
                    exercise: byName[item.name],
                    plannedSets: item.sets,
                    repLow: item.low,
                    repHigh: item.high,
                    restSeconds: item.rest,
                    supersetGroup: item.superset
                )
                context.insert(ri)
                routine.items.append(ri)
            }
        }

        try? context.save()
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

    private struct ItemPlan {
        let name: String
        let sets: Int
        let low: Int
        let high: Int
        let rest: Int
        var superset: Int?
    }

    private struct RoutinePlan {
        let name: String
        let items: [ItemPlan]
    }

    private static let starterRoutines: [RoutinePlan] = [
        RoutinePlan(name: "Push Day A", items: [
            ItemPlan(name: "Bench Press", sets: 4, low: 5, high: 8, rest: 180),
            ItemPlan(name: "Incline DB Press", sets: 3, low: 8, high: 10, rest: 120),
            ItemPlan(name: "Overhead Press", sets: 3, low: 6, high: 8, rest: 0, superset: 1),
            ItemPlan(name: "Lateral Raise", sets: 3, low: 12, high: 15, rest: 90, superset: 1),
            ItemPlan(name: "Cable Fly", sets: 3, low: 12, high: 15, rest: 90),
            ItemPlan(name: "Triceps Pushdown", sets: 3, low: 10, high: 12, rest: 90)
        ]),
        RoutinePlan(name: "Pull Day A", items: [
            ItemPlan(name: "Deadlift", sets: 3, low: 3, high: 5, rest: 210),
            ItemPlan(name: "Weighted Pull-Up", sets: 4, low: 6, high: 8, rest: 150),
            ItemPlan(name: "Barbell Row", sets: 4, low: 8, high: 10, rest: 120),
            ItemPlan(name: "Face Pull", sets: 3, low: 12, high: 15, rest: 60),
            ItemPlan(name: "Barbell Curl", sets: 3, low: 8, high: 12, rest: 90),
            ItemPlan(name: "Hammer Curl", sets: 3, low: 10, high: 12, rest: 60)
        ]),
        RoutinePlan(name: "Leg Day", items: [
            ItemPlan(name: "Back Squat", sets: 4, low: 5, high: 8, rest: 180),
            ItemPlan(name: "Romanian Deadlift", sets: 3, low: 8, high: 10, rest: 150),
            ItemPlan(name: "Leg Press", sets: 3, low: 10, high: 12, rest: 120),
            ItemPlan(name: "Leg Curl", sets: 3, low: 10, high: 12, rest: 90),
            ItemPlan(name: "Leg Extension", sets: 3, low: 12, high: 15, rest: 90),
            ItemPlan(name: "Standing Calf Raise", sets: 4, low: 10, high: 15, rest: 60),
            ItemPlan(name: "Hanging Leg Raise", sets: 3, low: 10, high: 15, rest: 60)
        ]),
        RoutinePlan(name: "Push Day B", items: [
            ItemPlan(name: "Incline Bench Press", sets: 4, low: 6, high: 8, rest: 150),
            ItemPlan(name: "DB Shoulder Press", sets: 3, low: 8, high: 10, rest: 120),
            ItemPlan(name: "Chest Dip", sets: 3, low: 8, high: 12, rest: 120),
            ItemPlan(name: "Cable Lateral Raise", sets: 3, low: 12, high: 15, rest: 60),
            ItemPlan(name: "Overhead Triceps Extension", sets: 3, low: 10, high: 12, rest: 90)
        ])
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
