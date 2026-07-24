import Foundation

/// Central brand configuration. The sister app ships from the same codebase
/// with a different compilation condition overriding these values — one
/// feature set, multiple brands.
enum Brand {
    #if SISTER
    // Placeholder — replaced when the sister brand's design lands.
    static let wordmark = "SISTER"
    static let plainName = "Sister"
    static let shareTag = "✦ SISTER"
    static let emptyStateTitle = "YOUR ERA STARTS NOW"
    static let emptyStateMessage = "No workouts logged yet. Start your first session and begin the climb."
    static let setupTitle = "YOUR WORKOUT, YOUR RULES"
    static let climbTitle = "THE CLIMB"
    static let rankNames = ["ROSE", "PEARL", "VALKYRIE", "GODDESS"]
    static let defaultFemaleBody = true
    #else
    static let wordmark = "TITΛN"
    static let plainName = "TITAN"
    static let shareTag = "⚔️ TITAN"
    static let emptyStateTitle = "THE FORGE AWAITS"
    static let emptyStateMessage = "No workouts logged yet. Start your first session to begin the climb from Bronze to Titan."
    static let setupTitle = "YOUR WORKOUT, YOUR RULES"
    static let climbTitle = "THE CLIMB"
    static let rankNames = ["BRONZE", "IRON", "SPARTAN", "TITAN"]
    static let defaultFemaleBody = false
    #endif

    static var firstRankName: String { "\(rankNames[0]) I" }
}
