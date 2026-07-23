import Foundation
import SwiftData

// MARK: - Enums

enum Equipment: String, Codable, CaseIterable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case cable = "Cable"
    case machine = "Machine"
    case bodyweight = "Bodyweight"
    case other = "Other"

    var abbrev: String {
        switch self {
        case .barbell: return "BB"
        case .dumbbell: return "DB"
        case .cable: return "CB"
        case .machine: return "MC"
        case .bodyweight: return "BW"
        case .other: return "OT"
        }
    }
}

enum Muscle: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case traps = "Traps"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case core = "Core"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
}

/// Coarse filter categories used by the exercise picker chips.
enum MuscleCategory: String, CaseIterable {
    case all = "All"
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case legs = "Legs"
    case arms = "Arms"
    case core = "Core"

    func contains(_ m: Muscle) -> Bool {
        switch self {
        case .all: return true
        case .chest: return m == .chest
        case .back: return m == .back || m == .traps
        case .shoulders: return m == .shoulders
        case .legs: return m == .quads || m == .hamstrings || m == .glutes || m == .calves
        case .arms: return m == .biceps || m == .triceps || m == .forearms
        case .core: return m == .core
        }
    }
}

enum SetType: String, Codable, CaseIterable {
    case warmup
    case working
    case failure
    case drop

    var badge: String {
        switch self {
        case .warmup: return "W"
        case .working: return ""
        case .failure: return "F"
        case .drop: return "D"
        }
    }
}

// MARK: - Models

@Model
final class Exercise {
    var name: String = ""
    var equipmentRaw: String = Equipment.barbell.rawValue
    var muscleRaw: String = Muscle.chest.rawValue
    var secondaryRaw: String = ""
    var isCustom: Bool = false
    var createdAt: Date = Date()

    init(name: String, equipment: Equipment, muscle: Muscle, secondary: [Muscle] = [], isCustom: Bool = false) {
        self.name = name
        self.equipmentRaw = equipment.rawValue
        self.muscleRaw = muscle.rawValue
        self.secondaryRaw = secondary.map { $0.rawValue }.joined(separator: ",")
        self.isCustom = isCustom
        self.createdAt = Date()
    }

    var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .other }
    var muscle: Muscle { Muscle(rawValue: muscleRaw) ?? .chest }
    var secondary: [Muscle] {
        secondaryRaw.split(separator: ",").compactMap { Muscle(rawValue: String($0)) }
    }
}

@Model
final class Routine {
    var name: String = ""
    var orderIndex: Int = 0
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var items: [RoutineItem] = []

    init(name: String, orderIndex: Int = 0) {
        self.name = name
        self.orderIndex = orderIndex
        self.createdAt = Date()
    }

    var sortedItems: [RoutineItem] {
        items.sorted { $0.orderIndex < $1.orderIndex }
    }
}

@Model
final class RoutineItem {
    var orderIndex: Int = 0
    var exercise: Exercise?
    var exerciseName: String = ""
    var plannedSets: Int = 3
    var repLow: Int = 8
    var repHigh: Int = 12
    var restSeconds: Int = 120
    var supersetGroup: Int?
    var routine: Routine?

    init(orderIndex: Int, exercise: Exercise?, plannedSets: Int = 3, repLow: Int = 8, repHigh: Int = 12, restSeconds: Int = 120, supersetGroup: Int? = nil) {
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.exerciseName = exercise?.name ?? ""
        self.plannedSets = plannedSets
        self.repLow = repLow
        self.repHigh = repHigh
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
    }

    var displayName: String { exercise?.name ?? exerciseName }
}

@Model
final class Workout {
    var title: String = ""
    var startedAt: Date = Date()
    var endedAt: Date?
    /// False while the athlete is still building the workout (setup mode);
    /// the clock starts when this flips to true.
    var hasBegun: Bool = true
    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.workout)
    var entries: [WorkoutEntry] = []

    init(title: String, startedAt: Date = Date()) {
        self.title = title
        self.startedAt = startedAt
    }

    var sortedEntries: [WorkoutEntry] {
        entries.sorted { $0.orderIndex < $1.orderIndex }
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

@Model
final class WorkoutEntry {
    var orderIndex: Int = 0
    var exercise: Exercise?
    var exerciseName: String = ""
    var restSeconds: Int = 120
    var supersetGroup: Int?
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.entry)
    var sets: [SetEntry] = []

    init(orderIndex: Int, exercise: Exercise?, restSeconds: Int = 120, supersetGroup: Int? = nil) {
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.exerciseName = exercise?.name ?? ""
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
    }

    var displayName: String { exercise?.name ?? exerciseName }

    var sortedSets: [SetEntry] {
        sets.sorted { $0.orderIndex < $1.orderIndex }
    }

    var completedSets: [SetEntry] {
        sortedSets.filter { $0.isCompleted }
    }
}

@Model
final class SetEntry {
    var orderIndex: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var typeRaw: String = SetType.working.rawValue
    var isCompleted: Bool = false
    var isPR: Bool = false
    var completedAt: Date?
    var entry: WorkoutEntry?

    init(orderIndex: Int, weight: Double, reps: Int, type: SetType = .working) {
        self.orderIndex = orderIndex
        self.weight = weight
        self.reps = reps
        self.typeRaw = type.rawValue
    }

    var type: SetType {
        get { SetType(rawValue: typeRaw) ?? .working }
        set { typeRaw = newValue.rawValue }
    }
}

@Model
final class BodyMetric {
    var date: Date = Date()
    var weight: Double?
    var chest: Double?
    var arm: Double?
    var waist: Double?

    init(date: Date = Date(), weight: Double? = nil, chest: Double? = nil, arm: Double? = nil, waist: Double? = nil) {
        self.date = date
        self.weight = weight
        self.chest = chest
        self.arm = arm
        self.waist = waist
    }
}

@Model
final class Supplement {
    var name: String = ""
    var serving: Double = 1
    var unit: String = "g"
    var orderIndex: Int = 0
    var createdAt: Date = Date()

    init(name: String, serving: Double, unit: String, orderIndex: Int = 0) {
        self.name = name
        self.serving = serving
        self.unit = unit
        self.orderIndex = orderIndex
        self.createdAt = Date()
    }
}

@Model
final class SupplementLog {
    var name: String = ""
    var amount: Double = 0
    var unit: String = "g"
    var date: Date = Date()
    var supplement: Supplement?

    init(supplement: Supplement, date: Date = Date()) {
        self.name = supplement.name
        self.amount = supplement.serving
        self.unit = supplement.unit
        self.date = date
        self.supplement = supplement
    }
}

@Model
final class Profile {
    var name: String = "ATHLETE"
    var xp: Int = 0
    var weeklyGoal: Int = 5
    var defaultRestSeconds: Int = 120
    var createdAt: Date = Date()

    init(name: String = "ATHLETE", weeklyGoal: Int = 5, defaultRestSeconds: Int = 120) {
        self.name = name
        self.weeklyGoal = weeklyGoal
        self.defaultRestSeconds = defaultRestSeconds
        self.createdAt = Date()
    }
}
