import SwiftUI

// Shared building blocks for every screen. Views compose these instead of
// restyling the same shapes by hand, so the whole app moves together.

// MARK: - Headers

/// The big condensed title at the top of each tab.
struct ScreenTitle<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.condensed(34, weight: .heavy))
                .kerning(1.5)
                .foregroundStyle(Color.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.top, 8)
    }
}

extension ScreenTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// Section label with an optional trailing text action.
struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(title)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.barlow(13.5, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                        .frame(minHeight: Layout.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Buttons

/// Round icon button with a full 44 pt hit area.
struct IconCircleButton: View {
    let systemName: String
    var size: CGFloat = 40
    var tint: Color = .textSoft
    var fill: Color = .surface2
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(fill))
                .frame(width: max(size, Layout.minTap), height: max(size, Layout.minTap))
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}

/// Quiet filled button for secondary actions.
struct SecondaryButton: View {
    let title: String
    var systemIcon: String?
    var height: CGFloat = 52
    let action: () -> Void

    init(_ title: String, systemIcon: String? = nil, height: CGFloat = 52, action: @escaping () -> Void) {
        self.title = title
        self.systemIcon = systemIcon
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.barlow(15.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color.textMain)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.surface2))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.strokeStrong, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}

/// Dashed outline button for "add something" actions.
struct DashedButton: View {
    let title: String
    var systemIcon: String = "plus"
    var height: CGFloat = 52
    let action: () -> Void

    init(_ title: String, systemIcon: String = "plus", height: CGFloat = 52, action: @escaping () -> Void) {
        self.title = title
        self.systemIcon = systemIcon
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemIcon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.barlow(15, weight: .semibold))
            }
            .foregroundStyle(Color.purpleBright)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.purplePrimary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Progress

struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 6
    var size: CGFloat = 44
    var track: Color = .surface2

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(
                    AngularGradient(colors: [.purpleDeep, .purplePrimary, .purpleBright, .purplePrimary], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

struct ThinProgressBar: View {
    let fraction: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.surface2)
                Capsule()
                    .fill(LinearGradient(colors: [.purpleDeep, .purplePrimary, .purpleBright], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Pickers

/// Capsule segmented control used for periods, units and metrics.
struct PillPicker<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button {
                    withAnimation(.snappy) { selection = option }
                    Haptics.selection()
                } label: {
                    Text(label(option))
                        .font(.barlow(13, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.white : Color.textDim)
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .background(Capsule().fill(selected ? Color.purplePrimary : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.surface))
        .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
    }
}

// MARK: - Number entry

/// A text field bound to a number that updates the model on every keystroke,
/// so a value is never lost when the keyboard is dismissed mid-edit.
struct NumberField: View {
    @Binding var value: Double
    var decimals: Bool = true
    var placeholder: String = "0"

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(decimals ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .monospacedDigit()
            .focused($focused)
            .onAppear { text = NumberField.format(value, decimals: decimals) }
            .onChange(of: text) { _, newText in
                if let v = NumberField.parse(newText) {
                    if abs(v - value) > 0.0001 { value = v }
                } else if newText.isEmpty, value != 0 {
                    // A cleared field is zero even mid-edit, so what's on
                    // screen is exactly what LOG SET records.
                    value = 0
                }
            }
            .onChange(of: value) { _, newValue in
                let shown = NumberField.parse(text) ?? 0
                if abs(shown - newValue) > 0.0001 {
                    text = NumberField.format(newValue, decimals: decimals)
                }
            }
            .onChange(of: focused) { _, isFocused in
                if isFocused {
                    // Start typing straight over an empty value.
                    if value == 0 { text = "" }
                } else {
                    if NumberField.parse(text) == nil { value = 0 }
                    text = NumberField.format(value, decimals: decimals)
                }
            }
    }

    /// Accepts "82,5" as well as "82.5". Pasted nonsense ("1e999", "nan") is
    /// rejected and anything huge is capped, so no stored value can overflow.
    static func parse(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let v = Double(t), v.isFinite else { return nil }
        return min(max(v, 0), 99_999)
    }

    static func format(_ v: Double, decimals: Bool) -> String {
        decimals ? Fmt.num(v) : String(v.roundedInt)
    }
}

/// Big − value + control for the set logger.
struct StepperField: View {
    let label: String
    @Binding var value: Double
    var step: Double = 1
    var decimals: Bool = false
    var height: CGFloat = 60
    var fontSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                stepButton("minus") { value = StepperField.snap(value, step: step, up: false) }
                NumberField(value: $value, decimals: decimals)
                    .font(.condensed(fontSize, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .frame(maxWidth: .infinity)
                stepButton("plus") { value = StepperField.snap(value, step: step, up: true) }
            }
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.hairline, lineWidth: 1))

            Text(label)
                .font(.barlow(11.5, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Color.textFaint)
        }
    }

    /// Moves to the next multiple of `step`, so odd values land back on the grid.
    static func snap(_ v: Double, step: Double, up: Bool) -> Double {
        guard step > 0 else { return v }
        let q = v / step
        let n = up ? (q + 1e-6).rounded(.down) + 1 : (q - 1e-6).rounded(.up) - 1
        return max(0, n * step)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.textSoft)
                .frame(width: 50, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(icon == "plus" ? "Increase \(label)" : "Decrease \(label)")
    }
}

// MARK: - Emblems & banners

/// Hexagon rank emblem with the logo bars and tier numeral.
struct RankEmblem: View {
    let rank: Rank
    var size: CGFloat = 72

    var body: some View {
        Hexagon()
            .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size * 1.1)
            .overlay(
                Hexagon()
                    .fill(LinearGradient(colors: [.surface2, .surface], startPoint: .top, endPoint: .bottom))
                    .padding(size * 0.045)
            )
            .overlay(
                VStack(spacing: size * 0.04) {
                    LogoBars(barWidth: size * 0.055, barHeight: size * 0.2, color: .glow, glowRadius: size * 0.07)
                    Text(rank.tierNumeral)
                        .font(.condensed(size * 0.2, weight: .heavy))
                        .kerning(1)
                        .foregroundStyle(Color.glow)
                }
            )
            .shadow(color: Color.purplePrimary.opacity(0.35), radius: size * 0.14)
    }
}

/// Celebration banner that drops in from the top when a record falls.
struct RecordToast: View {
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.18)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.condensed(19, weight: .heavy))
                    .kerning(1.5)
                Text(message)
                    .font(.barlow(14, weight: .semibold))
                    .opacity(0.92)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [.purpleBright, .purplePrimary, .purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: Color.purplePrimary.opacity(0.5), radius: 18, y: 6)
        .accessibilityElement(children: .combine)
    }
}

/// Friendly placeholder for empty lists.
struct EmptyStateCard: View {
    let systemIcon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemIcon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Color.purplePrimary.opacity(0.12)))
            Text(title)
                .font(.condensed(21, weight: .bold))
                .foregroundStyle(Color.textMain)
            Text(message)
                .font(.barlow(14))
                .foregroundStyle(Color.textDim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .card()
    }
}
