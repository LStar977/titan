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
        return Color.purplePrimary.opacity(0.16 + 0.78 * t)
    }

    private let bodyColor = Color(hex: 0x232333)

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 140
            let sy = size.height / 190

            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }
            /// Ellipse "blob" centered at (cx, cy), optionally rotated (degrees).
            func blob(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, rot: CGFloat = 0, _ color: Color) {
                let base = Path(ellipseIn: CGRect(x: -rx * sx, y: -ry * sy, width: 2 * rx * sx, height: 2 * ry * sy))
                let t = CGAffineTransform(translationX: cx * sx, y: cy * sy).rotated(by: rot * .pi / 180)
                ctx.fill(base.applying(t), with: .color(color))
            }
            func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: Color) {
                let rr = CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)
                ctx.fill(Path(roundedRect: rr, cornerRadius: r * sx), with: .color(color))
            }
            /// Thick round-capped polyline — used for limbs and limb muscles.
            func limb(_ pts: [(CGFloat, CGFloat)], _ lineWidth: CGFloat, _ color: Color) {
                guard pts.count > 1 else { return }
                var p = Path()
                p.move(to: P(pts[0].0, pts[0].1))
                for pt in pts.dropFirst() { p.addLine(to: P(pt.0, pt.1)) }
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: lineWidth * sx, lineCap: .round, lineJoin: .round))
            }

            // ---------- Neutral silhouette ----------

            // Head + neck (clear gap before the shoulder line)
            blob(70, 14, 9.5, 10.5, bodyColor)
            rrect(65, 23, 10, 9, 3.5, bodyColor)

            // Torso outline
            let shoulderX: CGFloat = female ? 47 : 43
            let waistX: CGFloat = female ? 58 : 55
            let hipX: CGFloat = female ? 50 : 52
            let shoulderY: CGFloat = female ? 39 : 38
            var torso = Path()
            torso.move(to: P(shoulderX, shoulderY))
            torso.addQuadCurve(to: P(140 - shoulderX, shoulderY), control: P(70, shoulderY - 9))
            torso.addQuadCurve(to: P(140 - waistX, 89), control: P(141 - shoulderX, 64))
            torso.addQuadCurve(to: P(140 - hipX, 105), control: P(142 - waistX, 97))
            torso.addQuadCurve(to: P(70, 111), control: P(82, 110))
            torso.addQuadCurve(to: P(hipX, 105), control: P(58, 110))
            torso.addQuadCurve(to: P(waistX, 89), control: P(waistX - 2, 97))
            torso.addQuadCurve(to: P(shoulderX, shoulderY), control: P(shoulderX - 1, 64))
            torso.closeSubpath()
            ctx.fill(torso, with: .color(bodyColor))
            ctx.stroke(torso, with: .color(.white.opacity(0.04)), lineWidth: 1)

            // Arms + legs
            let armTopX: CGFloat = female ? 45 : 42
            let armW: CGFloat = female ? 8 : 10
            limb([(armTopX, 41), (female ? 38 : 34, 71), (female ? 34 : 30, 99)], armW, bodyColor)
            limb([(140 - armTopX, 41), (female ? 102 : 106, 71), (female ? 106 : 110, 99)], armW, bodyColor)
            let legW: CGFloat = female ? 12 : 13
            limb([(60.5, 103), (58.5, 146), (59.5, 177)], legW, bodyColor)
            limb([(79.5, 103), (81.5, 146), (80.5, 177)], legW, bodyColor)

            // ---------- Muscles ----------

            if front {
                if female {
                    blob(48, 41.5, 6, 5, fill(.shoulders))
                    blob(92, 41.5, 6, 5, fill(.shoulders))
                    blob(60, 48, 8, 5.5, rot: -7, fill(.chest))
                    blob(80, 48, 8, 5.5, rot: 7, fill(.chest))
                    limb([(43, 51), (40, 66)], 7, fill(.biceps))
                    limb([(97, 51), (100, 66)], 7, fill(.biceps))
                    limb([(37, 75), (35, 93)], 5.5, fill(.forearms))
                    limb([(103, 75), (105, 93)], 5.5, fill(.forearms))
                    for y in [CGFloat(57), 65, 73] {
                        rrect(64.2, y, 5.4, 7.2, 2.2, fill(.core))
                        rrect(70.4, y, 5.4, 7.2, 2.2, fill(.core))
                    }
                    blob(59.5, 66, 2.8, 10, fill(.core, 0.6))
                    blob(80.5, 66, 2.8, 10, fill(.core, 0.6))
                    blob(62, 122, 7, 20, fill(.quads))
                    blob(78, 122, 7, 20, fill(.quads))
                    blob(60.5, 160, 4.5, 12, fill(.calves, 0.5))
                    blob(79.5, 160, 4.5, 12, fill(.calves, 0.5))
                } else {
                    blob(44, 41.5, 7, 5.5, fill(.shoulders))
                    blob(96, 41.5, 7, 5.5, fill(.shoulders))
                    blob(58.5, 49, 10, 6.5, rot: -7, fill(.chest))
                    blob(81.5, 49, 10, 6.5, rot: 7, fill(.chest))
                    limb([(40, 52), (36, 68)], 8.5, fill(.biceps))
                    limb([(100, 52), (104, 68)], 8.5, fill(.biceps))
                    limb([(33, 77), (31, 95)], 6.5, fill(.forearms))
                    limb([(107, 77), (109, 95)], 6.5, fill(.forearms))
                    for y in [CGFloat(58), 66.5, 75] {
                        rrect(63, y, 6.5, 7.6, 2.4, fill(.core))
                        rrect(70.5, y, 6.5, 7.6, 2.4, fill(.core))
                    }
                    blob(57.5, 68, 3.2, 11, fill(.core, 0.6))
                    blob(82.5, 68, 3.2, 11, fill(.core, 0.6))
                    blob(61, 121, 7.5, 21, fill(.quads))
                    blob(79, 121, 7.5, 21, fill(.quads))
                    blob(60, 160, 5, 13, fill(.calves, 0.5))
                    blob(80, 160, 5, 13, fill(.calves, 0.5))
                }
            } else {
                // Traps kite
                var traps = Path()
                let trapW: CGFloat = female ? 54 : 52
                let trapTop: CGFloat = female ? 29 : 28
                traps.move(to: P(70, trapTop))
                traps.addQuadCurve(to: P(trapW, 39), control: P(61, trapTop + 2))
                traps.addQuadCurve(to: P(70, 54), control: P(66, 46))
                traps.addQuadCurve(to: P(140 - trapW, 39), control: P(74, 46))
                traps.addQuadCurve(to: P(70, trapTop), control: P(79, trapTop + 2))
                traps.closeSubpath()
                ctx.fill(traps, with: .color(fill(.traps)))

                if female {
                    blob(48, 41.5, 5.5, 5, fill(.shoulders, 0.7))
                    blob(92, 41.5, 5.5, 5, fill(.shoulders, 0.7))
                    blob(60.5, 61, 8.5, 15, rot: 7, fill(.back))
                    blob(79.5, 61, 8.5, 15, rot: -7, fill(.back))
                    limb([(43, 51), (40, 66)], 7, fill(.triceps))
                    limb([(97, 51), (100, 66)], 7, fill(.triceps))
                    limb([(37, 75), (35, 93)], 5.5, fill(.forearms))
                    limb([(103, 75), (105, 93)], 5.5, fill(.forearms))
                    rrect(65.5, 78, 9, 11, 4, fill(.core, 0.5))
                    blob(60.5, 99, 9.5, 10.5, fill(.glutes))
                    blob(79.5, 99, 9.5, 10.5, fill(.glutes))
                    blob(61.5, 127, 6.5, 19, fill(.hamstrings))
                    blob(78.5, 127, 6.5, 19, fill(.hamstrings))
                    blob(60.5, 160, 5, 13, fill(.calves))
                    blob(79.5, 160, 5, 13, fill(.calves))
                } else {
                    blob(44, 41.5, 6.5, 5.5, fill(.shoulders, 0.7))
                    blob(96, 41.5, 6.5, 5.5, fill(.shoulders, 0.7))
                    blob(59, 63, 9.5, 17, rot: 7, fill(.back))
                    blob(81, 63, 9.5, 17, rot: -7, fill(.back))
                    limb([(40, 52), (36, 68)], 8.5, fill(.triceps))
                    limb([(100, 52), (104, 68)], 8.5, fill(.triceps))
                    limb([(33, 77), (31, 95)], 6.5, fill(.forearms))
                    limb([(107, 77), (109, 95)], 6.5, fill(.forearms))
                    rrect(64.5, 80, 11, 12, 4.5, fill(.core, 0.5))
                    blob(61, 98.5, 9, 9.5, fill(.glutes))
                    blob(79, 98.5, 9, 9.5, fill(.glutes))
                    blob(61, 125, 7, 19, fill(.hamstrings))
                    blob(79, 125, 7, 19, fill(.hamstrings))
                    blob(60, 159, 5.5, 14, fill(.calves))
                    blob(80, 159, 5.5, 14, fill(.calves))
                }
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
