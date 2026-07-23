import SwiftUI

// MARK: - Stat tile

struct StatTile: View {
    let label: String
    let value: String
    var unit: String = ""
    var glowing = false
    var footer: AnyView?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.barlow(10, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(glowing ? Color.glow : Color.textDim)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.condensed(32, weight: .bold))
                    .foregroundStyle(glowing ? Color.glow : Color.textMain)
                    .shadow(color: glowing ? Color.glow.opacity(0.5) : .clear, radius: 7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.condensed(17, weight: .bold))
                        .foregroundStyle(Color.textDim)
                }
            }
            if let footer { footer }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .card(14, border: glowing ? Color.glow.opacity(0.4) : .hairline)
    }
}

// MARK: - PR badge

struct PRBadge: View {
    var filled = false

    var body: some View {
        Text(filled ? "✦ PR" : "PR")
            .font(.barlow(9.5, weight: .bold))
            .kerning(1)
            .foregroundStyle(filled ? Color.bg : Color.glow)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(filled ? Color.glow : Color.glow.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(filled ? Color.clear : Color.glow.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.glow.opacity(filled ? 0.6 : 0.2), radius: 5)
    }
}

// MARK: - Streak pill

struct StreakPill: View {
    let days: Int
    var showLabel = true

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.purpleBright)
            Text("\(days)")
                .font(.condensed(16, weight: .bold))
                .foregroundStyle(Color.textMain)
            if showLabel {
                Text("day streak")
                    .font(.barlow(11, weight: .medium))
                    .foregroundStyle(Color.textDim)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.surface))
        .overlay(Capsule().stroke(Color.purplePrimary.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Charts

struct LineChart: View {
    let values: [Double]
    var height: CGFloat = 112
    var highlightLast = true

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Path { p in
                        let y = geo.size.height * CGFloat(i + 1) / 4
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                }
                if pts.count > 1 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        for pt in pts { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.purplePrimary.opacity(0.35), Color.purplePrimary.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(Color.purplePrimary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                if highlightLast, let last = pts.last {
                    Circle().fill(Color.glow.opacity(0.25)).frame(width: 16, height: 16).position(last)
                    Circle().fill(Color.glow).frame(width: 8, height: 8).position(last)
                }
            }
        }
        .frame(height: height)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = max(hi - lo, 1)
        let padTop: CGFloat = 10
        let padBottom: CGFloat = 6
        let h = size.height - padTop - padBottom
        if values.count == 1 {
            return [CGPoint(x: size.width - 10, y: padTop + h * 0.5)]
        }
        return values.enumerated().map { i, v in
            let x = 6 + (size.width - 16) * CGFloat(i) / CGFloat(values.count - 1)
            let y = padTop + h * (1 - CGFloat((v - lo) / span))
            return CGPoint(x: x, y: y)
        }
    }
}

struct BarChart: View {
    let values: [Double]
    var height: CGFloat = 76

    var body: some View {
        GeometryReader { geo in
            let hi = max(values.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: geo.size.width * 0.04) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(i == values.count - 1 ? Color.purpleBright : Color.purplePrimary.opacity(0.4))
                        .frame(height: max(4, geo.size.height * CGFloat(v / hi)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: height)
    }
}

struct Sparkline: View {
    let values: [Double]
    var width: CGFloat = 150
    var height: CGFloat = 42

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count > 1 {
                    Path { p in
                        p.move(to: pts[0])
                        for pt in pts.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(Color.purplePrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                if let last = pts.last {
                    Circle().fill(Color.purpleBright).frame(width: 6, height: 6).position(last)
                }
            }
        }
        .frame(width: width, height: height)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let lo = values.min() ?? 0
        let hi = values.max() ?? 1
        let span = max(hi - lo, 0.1)
        return values.enumerated().map { i, v in
            CGPoint(
                x: 3 + (size.width - 6) * CGFloat(i) / CGFloat(values.count - 1),
                y: 4 + (size.height - 8) * (1 - CGFloat((v - lo) / span))
            )
        }
    }
}

// MARK: - Muscle heat map silhouettes

struct BodyHeatMap: View {
    let front: Bool
    var female = false
    var width: CGFloat = 126
    var height: CGFloat = 188
    /// 0...1 intensity per muscle
    let intensity: (Muscle) -> Double

    private func fill(_ m: Muscle, _ weight: Double = 1.0) -> Color {
        let t = min(1, max(0, intensity(m) * weight))
        return Color.purplePrimary.opacity(0.10 + 0.85 * t)
    }

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 140
            let sy = size.height / 190

            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: Color) {
                let rr = CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)
                ctx.fill(Path(roundedRect: rr, cornerRadius: r * sx), with: .color(color))
            }
            func circle(_ cx: CGFloat, _ cy: CGFloat, _ radius: CGFloat, _ color: Color) {
                let rr = CGRect(x: (cx - radius) * sx, y: (cy - radius) * sy, width: radius * 2 * sx, height: radius * 2 * sy)
                ctx.fill(Path(ellipseIn: rr), with: .color(color))
            }

            // Head + neck (neutral)
            circle(70, 15, 11, .surface2)
            rect(64, 24, 12, 8, 3, .surface2)

            if female {
                if front {
                    circle(50, 40, 8, fill(.shoulders))
                    circle(90, 40, 8, fill(.shoulders))
                    rect(53, 34, 16, 17, 6, fill(.chest))
                    rect(71, 34, 16, 17, 6, fill(.chest))
                    rect(37, 47, 10, 22, 5, fill(.biceps))
                    rect(93, 47, 10, 22, 5, fill(.biceps))
                    rect(35, 72, 8, 24, 4, fill(.forearms))
                    rect(97, 72, 8, 24, 4, fill(.forearms))
                    rect(58, 53, 24, 30, 8, fill(.core))
                    rect(50, 86, 40, 12, 6, fill(.glutes, 0.5))
                    rect(51, 100, 17, 42, 7, fill(.quads))
                    rect(72, 100, 17, 42, 7, fill(.quads))
                    rect(54, 147, 12, 32, 6, fill(.calves, 0.6))
                    rect(74, 147, 12, 32, 6, fill(.calves, 0.6))
                } else {
                    rect(57, 27, 26, 9, 5, fill(.traps))
                    circle(50, 40, 8, fill(.shoulders, 0.7))
                    circle(90, 40, 8, fill(.shoulders, 0.7))
                    rect(54, 36, 16, 26, 6, fill(.back))
                    rect(70, 36, 16, 26, 6, fill(.back))
                    rect(37, 47, 10, 22, 5, fill(.triceps))
                    rect(93, 47, 10, 22, 5, fill(.triceps))
                    rect(35, 72, 8, 24, 4, fill(.forearms))
                    rect(97, 72, 8, 24, 4, fill(.forearms))
                    rect(60, 65, 20, 16, 7, fill(.core, 0.5))
                    rect(49, 84, 20, 18, 8, fill(.glutes))
                    rect(71, 84, 20, 18, 8, fill(.glutes))
                    rect(52, 105, 16, 38, 7, fill(.hamstrings))
                    rect(72, 105, 16, 38, 7, fill(.hamstrings))
                    rect(54, 148, 12, 31, 6, fill(.calves))
                    rect(74, 148, 12, 31, 6, fill(.calves))
                }
            } else if front {
                circle(46, 41, 10, fill(.shoulders))
                circle(94, 41, 10, fill(.shoulders))
                rect(50, 34, 19, 20, 7, fill(.chest))
                rect(71, 34, 19, 20, 7, fill(.chest))
                rect(31, 50, 11, 24, 5, fill(.biceps))
                rect(98, 50, 11, 24, 5, fill(.biceps))
                rect(29, 77, 9, 26, 4, fill(.forearms))
                rect(102, 77, 9, 26, 4, fill(.forearms))
                rect(56, 57, 28, 34, 9, fill(.core))
                rect(51, 95, 17, 46, 7, fill(.quads))
                rect(72, 95, 17, 46, 7, fill(.quads))
                rect(53, 146, 13, 34, 6, fill(.calves, 0.6))
                rect(74, 146, 13, 34, 6, fill(.calves, 0.6))
            } else {
                rect(54, 28, 32, 10, 5, fill(.traps))
                circle(46, 41, 10, fill(.shoulders, 0.7))
                circle(94, 41, 10, fill(.shoulders, 0.7))
                rect(50, 38, 19, 30, 7, fill(.back))
                rect(71, 38, 19, 30, 7, fill(.back))
                rect(31, 50, 11, 24, 5, fill(.triceps))
                rect(98, 50, 11, 24, 5, fill(.triceps))
                rect(29, 77, 9, 26, 4, fill(.forearms))
                rect(102, 77, 9, 26, 4, fill(.forearms))
                rect(58, 71, 24, 18, 7, fill(.core, 0.5))
                rect(52, 92, 17, 16, 7, fill(.glutes))
                rect(71, 92, 17, 16, 7, fill(.glutes))
                rect(51, 111, 17, 36, 7, fill(.hamstrings))
                rect(72, 111, 17, 36, 7, fill(.hamstrings))
                rect(53, 151, 13, 30, 6, fill(.calves))
                rect(74, 151, 13, 30, 6, fill(.calves))
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Custom header row (chevron back + label)

struct BackHeader: View {
    var label: String
    var trailing: AnyView?
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                    Text(label)
                        .font(.barlow(15, weight: .medium))
                }
                .foregroundStyle(Color.purpleBright)
            }
            .buttonStyle(.plain)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Empty little helpers

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
