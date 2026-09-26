import Foundation

/// Copy added in v1.1. Each property carries both brands inline, so neither
/// target can ever be missing a string.
extension Brand {
    /// Notification title when rest is over.
    static var restOverTitle: String {
        #if VALKYRIE
        return "Time to rise"
        #else
        return "Back to the bar"
        #endif
    }

    /// Banner shown the instant a record falls.
    static var prToastTitle: String {
        #if VALKYRIE
        return "NEW RECORD"
        #else
        return "NEW PR"
        #endif
    }

    static var rankUpTitle: String {
        #if VALKYRIE
        return "YOU ASCENDED"
        #else
        return "RANK UP"
        #endif
    }

    static var onboardingTagline: String {
        #if VALKYRIE
        return "Log every set. Celebrate every record. Rise from Ember to Immortal."
        #else
        return "Log every set. Catch every PR. Climb from Bronze to Titan."
        #endif
    }

    static var onboardingReady: String {
        #if VALKYRIE
        return "YOUR ASCENT STARTS NOW"
        #else
        return "THE FORGE IS LIT"
        #endif
    }

    /// Footer stamped on shared workout cards.
    static var shareFooter: String {
        #if VALKYRIE
        return "Tracked with VALKYRIE"
        #else
        return "Tracked with TITAN"
        #endif
    }

    /// The raw hex values behind the share card background.
    static var shareGradient: [UInt32] {
        #if VALKYRIE
        return [0xFF5C9D, 0xDB2777, 0x9D174D]
        #else
        return [0x2A1458, 0x140A2E, 0x0A0A0F]
        #endif
    }
}

/// Public pages that back the App Store listing.
enum Links {
    static let support = URL(string: "https://lstar977.github.io/titan/")!
    static let privacy = URL(string: "https://lstar977.github.io/titan/privacy/")!
}
