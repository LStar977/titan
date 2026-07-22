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

    static let bg = Color(hex: 0x0A0A0F)
    static let surface = Color(hex: 0x131320)
    static let surface2 = Color(hex: 0x1C1C2E)
    static let surface3 = Color(hex: 0x2A2A3E)
    static let purplePrimary = Color(hex: 0x8B5CF6)
    static let purpleBright = Color(hex: 0xA78BFA)
    static let purpleDeep = Color(hex: 0x5B21B6)
    static let purpleMid = Color(hex: 0x6D28D9)
    static let glow = Color(hex: 0xC4B5FD)
    static let textMain = Color(hex: 0xEDEDF4)
    static let textSoft = Color(hex: 0xC7C7D6)
    static let textDim = Color(hex: 0x8E8EA3)
    static let textFaint = Color(hex: 0x62627A)
    static let hairline = Color.white.opacity(0.05)
    static let successGreen = Color(hex: 0x34D399)
    static let dangerRed = Color(hex: 0xF87171)
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

// MARK: - Reusable styling

struct CardBackground: ViewModifier {
    var radius: CGFloat = 16
    var borderColor: Color = .hairline

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(borderColor, lineWidth: 1))
    }
}

extension View {
    func card(_ radius: CGFloat = 16, border: Color = .hairline) -> some View {
        modifier(CardBackground(radius: radius, borderColor: border))
    }
}

/// The primary purple CTA button used across the design.
struct GradientCTA: View {
    let title: String
    var systemIcon: String?
    var height: CGFloat = 52
    var fontSize: CGFloat = 19
    let action: () -> Void

    init(_ title: String, systemIcon: String? = nil, height: CGFloat = 52, fontSize: CGFloat = 19, action: @escaping () -> Void) {
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
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.condensed(fontSize, weight: .bold))
                    .kerning(2.5)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
            )
            .shadow(color: Color.purplePrimary.opacity(0.4), radius: 11)
        }
        .buttonStyle(.plain)
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
            bar.rotationEffect(.degrees(10))
            bar.rotationEffect(.degrees(-10))
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
            .font(.barlow(11, weight: .semibold))
            .kerning(2)
            .foregroundStyle(color)
    }
}

struct TagChip: View {
    let text: String
    var dim = false

    var body: some View {
        Text(text)
            .font(.barlow(11.5, weight: .medium))
            .foregroundStyle(dim ? Color.textDim : Color.textSoft)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.surface2))
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func pr() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
}

// MARK: - Formatting

enum Fmt {
    static func weight(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%.1f", v)
    }

    /// 42_300 -> "42.3k", 950 -> "950"
    static func volumeK(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.1fk", v / 1000) }
        return String(Int(v))
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }
}
