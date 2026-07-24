import Foundation
import SwiftUI

/// Central brand configuration. The VALKYRIE target compiles the same code
/// with the VALKYRIE condition set — one feature set, two apps.
enum Brand {
    #if VALKYRIE
    // MARK: VALKYRIE — bright, warm, empowering. Light theme.

    static let wordmark = "VALKYRIE"
    static let plainName = "VALKYRIE"
    static let wordmarkSize: CGFloat = 19
    static let wordmarkKerning: CGFloat = 3
    static let shareTag = "✦ VALKYRIE"
    static let emptyStateTitle = "THE ASCENT STARTS HERE"
    static let emptyStateMessage = "One set. That's all it takes to be someone who lifts. Start your first session and begin the ascent."
    static let completeTitle = "YOU ROSE TODAY"
    static let completeSubline: String? = "Earned, not given."
    static let setupTitle = "YOUR WORKOUT, YOUR RULES"
    static let climbTitle = "THE ASCENT"
    static let rankNames = ["EMBER", "SHIELDMAIDEN", "VALKYRIE", "IMMORTAL"]
    static let recordsTitle = "Recent Records"
    static let recordsTile = "Records"
    static let defaultFemaleBody = true
    static let isLight = true

    // Palette (from the VALKYRIE design handoff)
    static let bg: UInt32 = 0xFFF8F6
    static let surface: UInt32 = 0xFFFFFF
    static let surface2: UInt32 = 0xFAEEF1
    static let surface3: UInt32 = 0xF4E3E7
    static let primary: UInt32 = 0xEC4899
    static let primaryBright: UInt32 = 0xFF3D8B
    static let primaryDeep: UInt32 = 0xBE185D
    static let primaryMid: UInt32 = 0xDB2777
    static let glow: UInt32 = 0xFF3D8B
    static let textMain: UInt32 = 0x241A20
    static let textSoft: UInt32 = 0x4A3A42
    static let textDim: UInt32 = 0x8A7480
    static let textFaint: UInt32 = 0xB8A5AE
    static let success: UInt32 = 0x059669
    static let danger: UInt32 = 0xDC2626
    static let sheetBg: UInt32 = 0xFDF2F5
    static let surfaceRaised: UInt32 = 0xFFFFFF
    static let tabBarBg: UInt32 = 0xFFFDFC
    static let surfaceSunken: UInt32 = 0xFBE9EF
    static let outline: UInt32 = 0xE8B4C4
    static let neutralGear: UInt32 = 0xC9B4BC
    static let heatBody: UInt32 = 0xF4E3E7
    /// Hairlines & strokes on a light field are dark, not white.
    static let hairlineColor = Color.black.opacity(0.06)
    static let hairlineSoft = Color.black.opacity(0.045)
    static let strokeStrong = Color.black.opacity(0.09)
    /// Completed rank-emblem metals: Ember (warm copper) and Shieldmaiden (silver).
    static let rankLowGradient: [UInt32] = [0xFECBA1, 0xF59E42]
    static let rankLowText: UInt32 = 0x9A4A08
    static let rankMidGradient: [UInt32] = [0xE9EAEE, 0xB9BDC7]
    static let rankMidText: UInt32 = 0x4B5563

    #else
    // MARK: TITAN — dark, mythic. Dark theme.

    static let wordmark = "TITΛN"
    static let plainName = "TITAN"
    static let wordmarkSize: CGFloat = 21
    static let wordmarkKerning: CGFloat = 5
    static let shareTag = "⚔️ TITAN"
    static let emptyStateTitle = "THE FORGE AWAITS"
    static let emptyStateMessage = "No workouts logged yet. Start your first session to begin the climb from Bronze to Titan."
    static let completeTitle = "WORKOUT COMPLETE"
    static let completeSubline: String? = nil
    static let setupTitle = "YOUR WORKOUT, YOUR RULES"
    static let climbTitle = "THE CLIMB"
    static let rankNames = ["BRONZE", "IRON", "SPARTAN", "TITAN"]
    static let recordsTitle = "Recent PRs"
    static let recordsTile = "PRs Hit"
    static let defaultFemaleBody = false
    static let isLight = false

    static let bg: UInt32 = 0x0A0A0F
    static let surface: UInt32 = 0x131320
    static let surface2: UInt32 = 0x1C1C2E
    static let surface3: UInt32 = 0x2A2A3E
    static let primary: UInt32 = 0x8B5CF6
    static let primaryBright: UInt32 = 0xA78BFA
    static let primaryDeep: UInt32 = 0x5B21B6
    static let primaryMid: UInt32 = 0x6D28D9
    static let glow: UInt32 = 0xC4B5FD
    static let textMain: UInt32 = 0xEDEDF4
    static let textSoft: UInt32 = 0xC7C7D6
    static let textDim: UInt32 = 0x8E8EA3
    static let textFaint: UInt32 = 0x62627A
    static let success: UInt32 = 0x34D399
    static let danger: UInt32 = 0xF87171
    static let sheetBg: UInt32 = 0x10101B
    static let surfaceRaised: UInt32 = 0x17172A
    static let tabBarBg: UInt32 = 0x0C0C13
    static let surfaceSunken: UInt32 = 0x15151F
    static let outline: UInt32 = 0x3A3A4E
    static let neutralGear: UInt32 = 0x4A4A5E
    static let heatBody: UInt32 = 0x232333
    static let hairlineColor = Color.white.opacity(0.05)
    static let hairlineSoft = Color.white.opacity(0.04)
    static let strokeStrong = Color.white.opacity(0.08)
    /// Completed rank-emblem metals: Bronze and Iron.
    static let rankLowGradient: [UInt32] = [0x3A2E22, 0x241D15]
    static let rankLowText: UInt32 = 0xC9A97E
    static let rankMidGradient: [UInt32] = [0x3A3A4E, 0x23232E]
    static let rankMidText: UInt32 = 0xB9B9C8
    #endif

    static var firstRankName: String { "\(rankNames[0]) I" }
    static var colorScheme: ColorScheme { isLight ? .light : .dark }
}
