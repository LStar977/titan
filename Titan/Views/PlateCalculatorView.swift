import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var target: Double
    @State private var barWeight: Double = 45

    private let quickWeights: [Double] = [135, 185, 225, 275, 315]
    private let plates: [Double] = [45, 35, 25, 10, 5, 2.5]
    private let bars: [(label: String, weight: Double)] = [("45 lb bar", 45), ("35 lb bar", 35), ("60 lb trap bar", 60)]

    init(initialTarget: Double = 135) {
        _target = State(initialValue: max(45, (initialTarget / 5).rounded() * 5))
    }

    /// Plates per side, greedy.
    private var perSide: [(plate: Double, count: Int)] {
        var remaining = max(0, (target - barWeight) / 2)
        var out: [(Double, Int)] = []
        for p in plates {
            let n = Int(remaining / p)
            if n > 0 {
                out.append((p, n))
                remaining -= Double(n) * p
            }
        }
        return out
    }

    private var perSideWeight: Double {
        perSide.reduce(0) { $0 + $1.plate * Double($1.count) }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Color.clear.frame(width: 60, height: 1)
                Spacer()
                Text("PLATE CALCULATOR")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.top, 18)

            // Target stepper
            HStack(spacing: 18) {
                bigStep("minus") { target = max(barWeight, target - 5); Haptics.tap() }
                VStack(spacing: 2) {
                    Text(Fmt.weight(target))
                        .font(.condensed(62, weight: .heavy))
                        .foregroundStyle(Color.textMain)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("TARGET · LB")
                        .font(.barlow(10, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(Color.textDim)
                }
                .frame(minWidth: 130)
                bigStep("plus") { target += 5; Haptics.tap() }
            }

            // Quick chips
            HStack(spacing: 7) {
                ForEach(quickWeights, id: \.self) { w in
                    let sel = target == w
                    Button {
                        withAnimation(.snappy) { target = w }
                        Haptics.tap()
                    } label: {
                        Text(Fmt.weight(w))
                            .font(.condensed(15, weight: sel ? .bold : .semibold))
                            .foregroundStyle(sel ? .white : Color.textDim)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    sel
                                    ? AnyShapeStyle(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(Color.surface2)
                                )
                            )
                            .shadow(color: sel ? Color.purplePrimary.opacity(0.4) : .clear, radius: 6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Bar visualization
            VStack(spacing: 8) {
                barVisualization
                Group {
                    Text("\(Fmt.weight(barWeight)) lb bar · ")
                        .foregroundStyle(Color.textDim)
                    + Text("\(Fmt.weight(perSideWeight)) lb per side")
                        .font(.barlow(11, weight: .semibold))
                        .foregroundStyle(Color.textSoft)
                }
                .font(.barlow(11))
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .card(18)

            // Plate breakdown list
            if perSide.isEmpty {
                Text("Bar only — no plates needed")
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(perSide.enumerated()), id: \.offset) { i, item in
                        HStack {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(plateColor(item.plate))
                                    .frame(width: 12, height: plateListHeight(item.plate))
                                Text("\(Fmt.weight(item.plate)) lb")
                                    .font(.condensed(19, weight: .bold))
                                    .foregroundStyle(Color.textMain)
                            }
                            Spacer()
                            Group {
                                Text("× \(item.count) ")
                                    .font(.condensed(19, weight: .bold))
                                    .foregroundStyle(Color.textSoft)
                                + Text("per side")
                                    .font(.barlow(12))
                                    .foregroundStyle(Color.textFaint)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        if i < perSide.count - 1 {
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
                        withAnimation(.snappy) { barWeight = bar.weight }
                        Haptics.tap()
                    } label: {
                        Text(bar.label)
                            .font(.barlow(11.5, weight: .medium))
                            .foregroundStyle(sel ? Color.textSoft : Color.textDim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(sel ? Color.purplePrimary.opacity(0.1) : Color.clear))
                            .overlay(Capsule().stroke(sel ? Color.purplePrimary.opacity(0.5) : Color.surface3, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color.sheetBg.ignoresSafeArea())
        .presentationDetents([.fraction(0.78), .large])
        .presentationDragIndicator(.visible)
    }

    private func bigStep(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surface2)
                .frame(width: 52, height: 52)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.strokeStrong, lineWidth: 1))
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.textSoft)
                )
        }
        .buttonStyle(.plain)
    }

    private var barVisualization: some View {
        HStack(spacing: 3) {
            // Left sleeve end
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.neutralGear)
                .frame(width: 26, height: 8)
            plateStack(reversed: false)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.textFaint)
                .frame(width: 6, height: 22)
            Rectangle()
                .fill(Color.neutralGear)
                .frame(maxWidth: 86)
                .frame(height: 8)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.textFaint)
                .frame(width: 6, height: 22)
            plateStack(reversed: true)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.neutralGear)
                .frame(width: 26, height: 8)
        }
        .frame(height: 118)
        .frame(maxWidth: .infinity)
    }

    private func plateStack(reversed: Bool) -> some View {
        let expanded: [Double] = perSide.flatMap { Array(repeating: $0.plate, count: $0.count) }
        let ordered: [Double] = reversed ? Array(expanded.reversed()) : expanded
        return HStack(spacing: 3) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, p in
                RoundedRectangle(cornerRadius: 4)
                    .fill(plateColor(p))
                    .frame(width: plateWidth(p), height: plateHeight(p))
                    .shadow(color: p >= 45 ? Color.purplePrimary.opacity(0.35) : .clear, radius: 7)
            }
        }
    }

    private func plateColor(_ p: Double) -> Color {
        switch p {
        case 45: return .purplePrimary
        case 35: return .purpleBright
        case 25: return .purpleBright
        case 10: return .purpleMid
        case 5: return .purpleDeep
        default: return Color.textFaint
        }
    }

    private func plateHeight(_ p: Double) -> CGFloat {
        switch p {
        case 45: return 108
        case 35: return 94
        case 25: return 82
        case 10: return 58
        case 5: return 42
        default: return 30
        }
    }

    private func plateWidth(_ p: Double) -> CGFloat {
        switch p {
        case 45: return 14
        case 35: return 13
        case 25: return 12
        case 10: return 10
        case 5: return 8
        default: return 7
        }
    }

    private func plateListHeight(_ p: Double) -> CGFloat {
        switch p {
        case 45: return 22
        case 35: return 20
        case 25: return 18
        case 10: return 14
        case 5: return 11
        default: return 9
        }
    }
}
