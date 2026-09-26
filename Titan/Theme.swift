import SwiftUI
import UIKit

// MARK: - Colors (from the TITAN design system)

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    // All tokens resolve from the active Brand — TITAN (dark purple) or
    // VALKYRIE (light pink). Views only ever use these semantic names.
    static let bg = Color(hex: Brand.bg)
    static let surface = Color(hex: Brand.surface)
    static let surface2 = Color(hex: Brand.surface2)
    static let surface3 = Color(hex: Brand.surface3)
    static let purplePrimary = Color(hex: Brand.primary)
    static let purpleBright = Color(hex: Brand.primaryBright)
    static let purpleDeep = Color(hex: Brand.primaryDeep)
    static let purpleMid = Color(hex: Brand.primaryMid)
    static let glow = Color(hex: Brand.glow)
    static let textMain = Color(hex: Brand.textMain)
    static let textSoft = Color(hex: Brand.textSoft)
    static let textDim = Color(hex: Brand.textDim)
    static let textFaint = Color(hex: Brand.textFaint)
    static let hairline = Brand.hairlineColor
    static let hairlineSoft = Brand.hairlineSoft
    static let strokeStrong = Brand.strokeStrong
    static let successGreen = Color(hex: Brand.success)
    static let dangerRed = Color(hex: Brand.danger)
    static let sheetBg = Color(hex: Brand.sheetBg)
    static let surfaceRaised = Color(hex: Brand.surfaceRaised)
    static let tabBarBg = Color(hex: Brand.tabBarBg)
    static let surfaceSunken = Color(hex: Brand.surfaceSunken)
    static let outline = Color(hex: Brand.outline)
    static let neutralGear = Color(hex: Brand.neutralGear)
    static let heatBody = Color(hex: Brand.heatBody)

    /// The brand's two-stop accent gradient, used for primary actions.
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Fonts

extension Font {
    static func barlow(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium: name = "Barlow-Medium"
        case .semibold: name = "Barlow-SemiBold"
        case .bold, .heavy, .black: name = "Barlow-Bold"
        default: name = "Barlow-Regular"
        }
        return .custom(name, size: size)
    }

    static func condensed(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .medium: name = "BarlowCondensed-Medium"
        case .semibold: name = "BarlowCondensed-SemiBold"
        case .heavy, .black: name = "BarlowCondensed-ExtraBold"
        default: name = "BarlowCondensed-Bold"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Layout tokens

enum Layout {
    /// Horizontal page margin on every tab.
    static let screenPad: CGFloat = 20
    /// Default card corner radius.
    static let cardRadius: CGFloat = 18
    /// Nothing tappable is shorter than this.
    static let minTap: CGFloat = 44
    /// Space the floating tab bar needs at the bottom of scrolling pages.
    static let tabBarClearance: CGFloat = 130
}

// MARK: - Cards

struct CardBackground: ViewModifier {
    var radius: CGFloat = Layout.cardRadius
    var borderColor: Color = .hairline

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.surface)
                    // Light theme reads flat without a whisper of depth.
                    .shadow(color: Brand.isLight ? Color.black.opacity(0.05) : .clear, radius: 10, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    func card(_ radius: CGFloat = Layout.cardRadius, border: Color = .hairline) -> some View {
        modifier(CardBackground(radius: radius, borderColor: border))
    }
}

// MARK: - Buttons

/// Gentle press-down scale so every tap feels physical.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// The primary gradient call to action.
struct GradientCTA: View {
    let title: String
    var systemIcon: String?
    var height: CGFloat = 56
    var fontSize: CGFloat = 19
    let action: () -> Void

    init(_ title: String, systemIcon: String? = nil, height: CGFloat = 56, fontSize: CGFloat = 19, action: @escaping () -> Void) {
        self.title = title
        self.systemIcon = systemIcon
        self.height = height
        self.fontSize = fontSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 15, weight: .bold))
                }
                Text(title)
                    .font(.condensed(fontSize, weight: .bold))
                    .kerning(2.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.purplePrimary.opacity(Brand.isLight ? 0.28 : 0.4), radius: 12, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}

/// Pointy-top hexagon used for rank emblems.
struct Hexagon: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.25))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.75))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.75))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.25))
        p.closeSubpath()
        return p
    }
}

/// The two glowing angled bars from the TITAN logo mark.
struct LogoBars: View {
    var barWidth: CGFloat = 4
    var barHeight: CGFloat = 12
    var color: Color = .purpleBright
    var glowRadius: CGFloat = 3

    var body: some View {
        HStack(spacing: barWidth) {
            bar.rotationEffect(.degrees(12))
            bar.rotationEffect(.degrees(-12))
        }
    }

    private var bar: some View {
        RoundedRectangle(cornerRadius: barWidth / 2)
            .fill(color)
            .frame(width: barWidth, height: barHeight)
            .shadow(color: color.opacity(0.9), radius: glowRadius)
    }
}

/// Small uppercase tracked section label.
struct SectionLabel: View {
    let text: String
    var color: Color = .textDim

    init(_ text: String, color: Color = .textDim) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.barlow(12, weight: .semibold))
            .kerning(1.8)
            .foregroundStyle(color)
    }
}

struct TagChip: View {
    let text: String
    var dim = false

    var body: some View {
        Text(text)
            .font(.barlow(12.5, weight: .medium))
            .foregroundStyle(dim ? Color.textDim : Color.textSoft)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.surface2))
    }
}

// MARK: - Keyboard

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    /// A personal record: a solid thump followed by the success pattern.
    static func pr() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    /// Rest is over — distinct from a logged set so it can be felt in a pocket.
    static func restDone() {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { gen.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { gen.impactOccurred() }
    }
}

// MARK: - Formatting

enum Fmt {
    /// The athlete's display unit. Reading it inside a view body keeps that
    /// view in sync when the unit changes.
    static var unit: WeightUnit { Prefs.shared.unit }
    static var unitLabel: String { unit.label }

    /// A plain number with up to `decimals` places and no trailing zeros:
    /// 5 → "5", 2.50 → "2.5", 101.25 → "101.25".
    static func num(_ v: Double, decimals: Int = 2) -> String {
        guard v.isFinite else { return "0" }
        var s = String(format: "%.\(decimals)f", v)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s == "-0" ? "0" : s
    }

    /// Stored pounds shown in the athlete's unit, without a suffix.
    static func weight(_ lb: Double) -> String { num(unit.fromLb(lb)) }

    /// Stored pounds with the unit: "185 lb".
    static func weightU(_ lb: Double) -> String { "\(weight(lb)) \(unitLabel)" }

    /// Stored pounds rounded to a whole number in the athlete's unit (e1RM).
    static func whole(_ lb: Double) -> String { String(Int(unit.fromLb(lb).rounded())) }

    /// Stored pounds as compact volume: 42_300 → "42.3k".
    static func volumeK(_ lb: Double) -> String { compact(unit.fromLb(lb)) }

    /// A value already in display units, compacted: 1_250_000 → "1.25M".
    static func compact(_ v: Double) -> String {
        if v >= 1_000_000 { return num(v / 1_000_000, decimals: 2) + "M" }
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return String(Int(v.rounded()))
    }

    /// Stored inches shown as inches or centimetres.
    static func length(_ inches: Double) -> String { num(unit.fromInches(inches), decimals: 1) }

    /// Rest-timer style: 83 → "1:23".
    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Workout length: "58 min", "1 h 12 min".
    static func duration(_ t: TimeInterval) -> String {
        let m = max(0, Int((t / 60).rounded()))
        if m < 60 { return "\(m) min" }
        let h = m / 60
        let r = m % 60
        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }

    /// Compact hours for lifetime totals: "37.5 h".
    static func hours(_ t: TimeInterval) -> String {
        let h = t / 3600
        return h < 10 ? num(h, decimals: 1) + " h" : "\(Int(h.rounded())) h"
    }

    static func shortDate(_ d: Date) -> String { shortFormatter.string(from: d) }
    static func dayLabel(_ d: Date) -> String { dayFormatter.string(from: d) }
    static func monthYear(_ d: Date) -> String { monthFormatter.string(from: d) }
    static func time(_ d: Date) -> String { timeFormatter.string(from: d) }

    /// "Today", "Yesterday", "3 days ago", otherwise "Sep 22".
    static func relative(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: cal.startOfDay(for: Date())).day ?? 0
        if days > 1 && days < 7 { return "\(days) days ago" }
        return shortDate(d)
    }

    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
