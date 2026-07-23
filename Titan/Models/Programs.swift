import Foundation
import SwiftData

// MARK: - Popular program templates (static library, not stored)

struct ProgramItem {
    let name: String
    let sets: Int
    let low: Int
    let high: Int
    let rest: Int
    var superset: Int?

    init(_ name: String, _ sets: Int, _ low: Int, _ high: Int, rest: Int, superset: Int? = nil) {
        self.name = name
        self.sets = sets
        self.low = low
        self.high = high
        self.rest = rest
        self.superset = superset
    }
}

struct ProgramDay: Identifiable {
    var id: String { name }
    let name: String
    let items: [ProgramItem]
}

struct Program: Identifiable {
    var id: String { name }
    let name: String
    let tagline: String
    let blurb: String
    let days: [ProgramDay]
}

enum ProgramLibrary {
    static let all: [Program] = [ppl, startingStrength, strongLifts, upperLower]

    /// Copies the program's days into the athlete's routines and makes them the split.
    static func adopt(_ program: Program, context: ModelContext, routines: [Routine], exercises: [Exercise]) {
        for r in routines {
            r.scheduleIndex = nil
        }
        var byName: [String: Exercise] = [:]
        for e in exercises where byName[e.name] == nil {
            byName[e.name] = e
        }
        let base = (routines.map { $0.orderIndex }.max() ?? -1) + 1
        for (i, day) in program.days.enumerated() {
            let routine = Routine(name: day.name, orderIndex: base + i)
            routine.scheduleIndex = i
            context.insert(routine)
            for (j, item) in day.items.enumerated() {
                let ri = RoutineItem(
                    orderIndex: j,
                    exercise: byName[item.name],
                    plannedSets: item.sets,
                    repLow: item.low,
                    repHigh: item.high,
                    restSeconds: item.rest,
                    supersetGroup: item.superset
                )
                if ri.exercise == nil {
                    ri.exerciseName = item.name
                }
                context.insert(ri)
                routine.items.append(ri)
            }
        }
        try? context.save()
    }

    // MARK: Programs

    static let ppl = Program(
        name: "Push / Pull / Legs",
        tagline: "The classic 3-day split",
        blurb: "Push muscles one day, pull muscles the next, legs the third. Run it once (3 days/week) or twice (6 days/week). The most popular split in modern bodybuilding for a reason.",
        days: [
            ProgramDay(name: "Push Day", items: [
                ProgramItem("Bench Press", 4, 5, 8, rest: 180),
                ProgramItem("Overhead Press", 3, 8, 10, rest: 120),
                ProgramItem("Incline DB Press", 3, 8, 12, rest: 90),
                ProgramItem("Lateral Raise", 3, 12, 15, rest: 60),
                ProgramItem("Triceps Pushdown", 3, 10, 12, rest: 60),
                ProgramItem("Overhead Triceps Extension", 3, 10, 12, rest: 60)
            ]),
            ProgramDay(name: "Pull Day", items: [
                ProgramItem("Deadlift", 3, 3, 5, rest: 210),
                ProgramItem("Pull-Up", 3, 6, 10, rest: 120),
                ProgramItem("Barbell Row", 4, 8, 10, rest: 120),
                ProgramItem("Face Pull", 3, 12, 15, rest: 60),
                ProgramItem("Barbell Curl", 3, 8, 12, rest: 60),
                ProgramItem("Hammer Curl", 3, 10, 12, rest: 60)
            ]),
            ProgramDay(name: "Leg Day", items: [
                ProgramItem("Back Squat", 4, 5, 8, rest: 180),
                ProgramItem("Romanian Deadlift", 3, 8, 10, rest: 150),
                ProgramItem("Leg Press", 3, 10, 12, rest: 120),
                ProgramItem("Leg Curl", 3, 10, 12, rest: 90),
                ProgramItem("Standing Calf Raise", 4, 10, 15, rest: 60)
            ])
        ]
    )

    static let startingStrength = Program(
        name: "Starting Strength",
        tagline: "Beginner barbell strength, A/B",
        blurb: "Two alternating full-body days built around the big barbell lifts. Add weight every session. The proven way to build a strength base fast.",
        days: [
            ProgramDay(name: "Strength A", items: [
                ProgramItem("Back Squat", 3, 5, 5, rest: 180),
                ProgramItem("Bench Press", 3, 5, 5, rest: 180),
                ProgramItem("Deadlift", 1, 5, 5, rest: 300)
            ]),
            ProgramDay(name: "Strength B", items: [
                ProgramItem("Back Squat", 3, 5, 5, rest: 180),
                ProgramItem("Overhead Press", 3, 5, 5, rest: 180),
                ProgramItem("Barbell Row", 3, 5, 5, rest: 180)
            ])
        ]
    )

    static let strongLifts = Program(
        name: "StrongLifts 5×5",
        tagline: "Five sets of five, A/B",
        blurb: "Two alternating workouts, 5 sets of 5 on every lift. Simple, brutal, effective — add 5 lb each session and watch the bar bend.",
        days: [
            ProgramDay(name: "5×5 A", items: [
                ProgramItem("Back Squat", 5, 5, 5, rest: 180),
                ProgramItem("Bench Press", 5, 5, 5, rest: 180),
                ProgramItem("Barbell Row", 5, 5, 5, rest: 180)
            ]),
            ProgramDay(name: "5×5 B", items: [
                ProgramItem("Back Squat", 5, 5, 5, rest: 180),
                ProgramItem("Overhead Press", 5, 5, 5, rest: 180),
                ProgramItem("Deadlift", 1, 5, 5, rest: 300)
            ])
        ]
    )

    static let upperLower = Program(
        name: "Upper / Lower",
        tagline: "4-day strength & size split",
        blurb: "Alternate upper-body and lower-body days, four days a week. The sweet spot between frequency and recovery for most intermediate lifters.",
        days: [
            ProgramDay(name: "Upper A", items: [
                ProgramItem("Bench Press", 4, 6, 8, rest: 150),
                ProgramItem("Barbell Row", 4, 6, 8, rest: 150),
                ProgramItem("Overhead Press", 3, 8, 10, rest: 120),
                ProgramItem("Lat Pulldown", 3, 8, 12, rest: 90),
                ProgramItem("Barbell Curl", 2, 10, 12, rest: 60),
                ProgramItem("Triceps Pushdown", 2, 10, 12, rest: 60)
            ]),
            ProgramDay(name: "Lower A", items: [
                ProgramItem("Back Squat", 4, 6, 8, rest: 180),
                ProgramItem("Romanian Deadlift", 3, 8, 10, rest: 150),
                ProgramItem("Leg Press", 3, 10, 12, rest: 120),
                ProgramItem("Leg Curl", 3, 10, 12, rest: 90),
                ProgramItem("Standing Calf Raise", 3, 12, 15, rest: 60)
            ]),
            ProgramDay(name: "Upper B", items: [
                ProgramItem("Overhead Press", 4, 6, 8, rest: 150),
                ProgramItem("Weighted Pull-Up", 4, 6, 8, rest: 150),
                ProgramItem("Incline DB Press", 3, 8, 10, rest: 120),
                ProgramItem("Seated Cable Row", 3, 8, 12, rest: 90),
                ProgramItem("Hammer Curl", 2, 10, 12, rest: 60),
                ProgramItem("Skull Crusher", 2, 10, 12, rest: 60)
            ]),
            ProgramDay(name: "Lower B", items: [
                ProgramItem("Deadlift", 3, 3, 5, rest: 210),
                ProgramItem("Front Squat", 3, 6, 8, rest: 180),
                ProgramItem("Bulgarian Split Squat", 3, 8, 10, rest: 120),
                ProgramItem("Leg Extension", 3, 12, 15, rest: 90),
                ProgramItem("Seated Calf Raise", 3, 12, 15, rest: 60)
            ])
        ]
    )
}
