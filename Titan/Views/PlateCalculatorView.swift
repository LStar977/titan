import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    /// Target and bar are held in the athlete's display unit.
    @State private var target: Double
    @State private var barWeight: Double

    private let unit: WeightUnit

    init(initialTargetLb: Double = 135) {
        let unit = Prefs.shared.unit
        self.unit = unit
        let shown = unit.fromLb(initialTargetLb)
        let step = unit.step
        _target = State(initialValue: max(unit.barWeight, (shown / step).rounded() * step))
        _barWeight = State(initialValue: unit.barWeight)
    }

    private var quickWeights: [Double] {
        unit == .lb ? [135, 185, 225, 275, 315] : [60, 80, 100, 120, 140]
    }

    private var bars: [(label: String, weight: Double)] {
        unit == .lb
            ? [("45 lb bar", 45), ("35 lb bar", 35), ("60 lb trap bar", 60)]
            : [("20 kg bar", 20), ("15 kg bar", 15), ("25 kg trap bar", 25)]
    }

    private var result: (plates: [Double], remainder: Double) {
        PlateMath.perSide(target: target, bar: barWeight, unit: unit)
    }

    /// Plates grouped for the list: 45 × 2, 10 × 1…
    private var grouped: [(plate: Double, count: Int)] {
        var out: [(plate: Double, count: Int)] = []
        for p in result.plates {
            if let last = out.last, last.plate == p {
                out[out.count - 1] = (p, last.count + 1)
            } else {
                out.append((p, 1))
            }
        }
        return out
    }

    private var perSideWeight: Double {
        result.plates.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Color.clear.frame(width: 60, height: 1)
                Spacer()
                Text("PLATE CALCULATOR")
                    .font(.condensed(20, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.barlow(16, weight: .semibold))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.top, 18)

            // Target stepper
            HStack(spacing: 18) {
                bigStep("minus") {
                    target = max(barWeight, StepperField.snap(target, step: unit.step, up: false))
                }
                VStack(spacing: 2) {
                    Text(Fmt.num(target))
                        .font(.condensed(64, weight: .heavy))
                        .foregroundStyle(Color.textMain)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("TARGET · \(unit.label.uppercased())")
                        .font(.barlow(12, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(Color.textDim)
                }
                .frame(minWidth: 140)
                bigStep("plus") {
                    target = StepperField.snap(target, step: unit.step, up: true)
                }
            }

            // Quick chips
            HStack(spacing: 7) {
                ForEach(quickWeights, id: \.self) { w in
                    let sel = target == w
                    Button {
                        withAnimation(.snappy) { target = w }
                        Haptics.selection()
                    } label: {
                        Text(Fmt.num(w))
                            .font(.condensed(17, weight: sel ? .bold : .semibold))
                            .foregroundStyle(sel ? Color.white : Color.textDim)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background {
                                if sel {
                                    Capsule().fill(Color.accentGradient)
                                } else {
                                    Capsule().fieldFill()
                                }
                            }
                            .shadow(color: sel ? Color.purplePrimary.opacity(0.4) : .clear, radius: 6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Bar visualization
            VStack(spacing: 10) {
                barVisualization
                Group {
                    Text("\(Fmt.num(barWeight)) \(unit.label) bar · ")
                        .foregroundStyle(Color.textDim)
                    + Text("\(Fmt.num(perSideWeight)) \(unit.label) per side")
                        .font(.barlow(13, weight: .semibold))
                        .foregroundStyle(Color.textSoft)
                }
                .font(.barlow(13))
                if result.remainder > 0.01 {
                    Text("Closest loadable: \(Fmt.num(barWeight + perSideWeight * 2)) \(unit.label)")
                        .font(.barlow(12.5, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .card(20)

            // Plate breakdown list
            if grouped.isEmpty {
                Text("Just the bar — no plates needed")
                    .font(.barlow(15))
                    .foregroundStyle(Color.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(grouped.enumerated()), id: \.offset) { i, item in
                        HStack {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(plateColor(item.plate))
                                    .frame(width: 12, height: plateListHeight(item.plate))
                                Text("\(Fmt.num(item.plate)) \(unit.label)")
                                    .font(.condensed(21, weight: .bold))
                                    .foregroundStyle(Color.textMain)
                            }
                            Spacer()
                            Group {
                                Text("× \(item.count) ")
                                    .font(.condensed(21, weight: .bold))
                                    .foregroundStyle(Color.textSoft)
                                + Text("per side")
                                    .font(.barlow(13))
                                    .foregroundStyle(Color.textFaint)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        if i < grouped.count - 1 {
                            Divider().overlay(Color.hairlineSoft)
                        }
                    }
                }
                .card()
            }

            // Bar selection
            HStack(spacing: 7) {
                ForEach(bars, id: \.weight) { bar in
                    let sel = barWeight == bar.weight
                    Button {
                        withAnimation(.snappy) {
                            barWeight = bar.weight
                            target = max(target, bar.weight)
                        }
                        Haptics.selection()
                    } label: {
                        Text(bar.label)
                            .font(.barlow(13, weight: .medium))
                            .foregroundStyle(sel ? Color.textMain : Color.textDim)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(Capsule().fill(sel ? Color.purplePrimary.opacity(0.12) : Color.clear))
                            .overlay(Capsule().stroke(sel ? Color.purplePrimary.opacity(0.55) : Color.surface3, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Layout.screenPad)
        .background(Color.sheetBg.ignoresSafeArea())
        .presentationDetents([.fraction(0.82), .large])
        .presentationDragIndicator(.visible)
    }

    private func bigStep(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fieldFill()
                .frame(width: 56, height: 56)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.isLight ? Color.clear : Color.strokeStrong, lineWidth: 1))
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.textSoft)
                )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(icon == "plus" ? "Heavier" : "Lighter")
    }

    private var barVisualization: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.neutralGear)
                .frame(width: 22, height: 8)
            plateStack(reversed: false)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.textFaint)
                .frame(width: 6, height: 22)
            Rectangle()
                .fill(Color.neutralGear)
                .frame(maxWidth: 80)
                .frame(height: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.textFaint)
                .frame(width: 6, height: 22)
            plateStack(reversed: true)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.neutralGear)
                .frame(width: 22, height: 8)
        }
        .frame(height: 118)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func plateStack(reversed: Bool) -> some View {
        let ordered: [Double] = reversed ? Array(result.plates.reversed()) : result.plates
        return HStack(spacing: 3) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, p in
                RoundedRectangle(cornerRadius: 4)
                    .fill(plateColor(p))
                    .frame(width: plateWidth(p), height: plateHeight(p))
                    .shadow(color: rank(p) == 0 ? Color.purplePrimary.opacity(0.35) : .clear, radius: 7)
            }
        }
    }

    /// Position of a plate in this unit's set, heaviest = 0.
    private func rank(_ p: Double) -> Int {
        PlateMath.plates(for: unit).firstIndex(of: p) ?? 6
    }

    private func plateColor(_ p: Double) -> Color {
        switch rank(p) {
        case 0: return .purplePrimary
        case 1, 2: return .purpleBright
        case 3: return .purpleMid
        case 4: return .purpleDeep
        default: return .textFaint
        }
    }

    private func plateHeight(_ p: Double) -> CGFloat {
        let heights: [CGFloat] = [108, 96, 84, 62, 46, 34, 28]
        return heights[min(rank(p), 6)]
    }

    private func plateWidth(_ p: Double) -> CGFloat {
        let widths: [CGFloat] = [14, 13, 12, 10, 8, 7, 6]
        return widths[min(rank(p), 6)]
    }

    private func plateListHeight(_ p: Double) -> CGFloat {
        let heights: [CGFloat] = [22, 20, 18, 14, 11, 9, 8]
        return heights[min(rank(p), 6)]
    }
}
