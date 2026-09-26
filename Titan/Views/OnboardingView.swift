import SwiftUI
import SwiftData

/// First launch only: name, units, weekly goal, rest alerts — then straight
/// into a first workout. Every step can be changed later in Settings.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var step = 0
    @State private var name = ""
    @State private var unit: WeightUnit = WeightUnit.localeDefault
    @State private var goal = 4
    @FocusState private var nameFocused: Bool

    private let lastStep = 5

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Color.purplePrimary.opacity(0.24), .clear],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 0, endRadius: 360
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)

                Spacer(minLength: 20)

                Group {
                    switch step {
                    case 0: welcome
                    case 1: nameStep
                    case 2: unitStep
                    case 3: goalStep
                    case 4: alertsStep
                    default: readyStep
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer(minLength: 20)

                buttons
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            if step > 0 && step < lastStep {
                Button {
                    go(to: step - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textSoft)
                        .frame(width: Layout.minTap, height: Layout.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: Layout.minTap, height: Layout.minTap)
            }
            Spacer()
            if step > 0 {
                HStack(spacing: 6) {
                    ForEach(1...lastStep, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Color.purplePrimary : Color.surface3)
                            .frame(width: i == step ? 22 : 8, height: 8)
                    }
                }
                .animation(.snappy, value: step)
            }
            Spacer()
            Color.clear.frame(width: Layout.minTap, height: Layout.minTap)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        switch step {
        case 0:
            GradientCTA("GET STARTED", systemIcon: "arrow.right") { go(to: 1) }
        case 1:
            GradientCTA(name.trimmingCharacters(in: .whitespaces).isEmpty ? "SKIP" : "CONTINUE") {
                nameFocused = false
                go(to: 2)
            }
        case 2:
            GradientCTA("CONTINUE") { go(to: 3) }
        case 3:
            GradientCTA("CONTINUE") { go(to: 4) }
        case 4:
            VStack(spacing: 10) {
                GradientCTA("TURN ON REST ALERTS", systemIcon: "bell.fill") {
                    Prefs.shared.setRestAlerts(true)
                    RestAlerts.request { _ in go(to: lastStep) }
                }
                Button {
                    Prefs.shared.setRestAlerts(false)
                    go(to: lastStep)
                } label: {
                    Text("Not now")
                        .font(.barlow(16, weight: .semibold))
                        .foregroundStyle(Color.textDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        default:
            VStack(spacing: 10) {
                GradientCTA("START MY FIRST WORKOUT", systemIcon: "play.fill") {
                    finish(startWorkout: true)
                }
                SecondaryButton("I'll look around first") {
                    finish(startWorkout: false)
                }
            }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.purplePrimary.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                Hexagon()
                    .fill(LinearGradient(colors: [.surface2, .surface], startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 132)
                    .overlay(Hexagon().stroke(Color.purplePrimary.opacity(0.55), lineWidth: 2))
                    .overlay(LogoBars(barWidth: 9, barHeight: 34, glowRadius: 10))
            }
            Text(Brand.wordmark)
                .font(.condensed(52, weight: .heavy))
                .kerning(Brand.wordmarkKerning * 2)
                .foregroundStyle(Color.textMain)
                .brandGlow(Color.purplePrimary.opacity(0.45), radius: 16)
            Text(Brand.onboardingTagline)
                .font(.barlow(18))
                .lineSpacing(4)
                .foregroundStyle(Color.textSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
    }

    private var nameStep: some View {
        VStack(spacing: 18) {
            stepTitle("WHAT SHOULD WE CALL YOU?")
            TextField("Your first name", text: $name)
                .font(.condensed(34, weight: .bold))
                .foregroundStyle(Color.textMain)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit { go(to: 2) }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(nameFocused ? Color.purplePrimary : Color.outline)
                        .frame(height: 2)
                }
                .padding(.horizontal, 20)
            stepCaption("It's just for your dashboard greeting.")
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nameFocused = true }
        }
    }

    private var unitStep: some View {
        VStack(spacing: 22) {
            stepTitle("HOW DO YOU LOAD THE BAR?")
            HStack(spacing: 12) {
                unitCard(.lb, big: "LB", small: "Pounds")
                unitCard(.kg, big: "KG", small: "Kilograms")
            }
            stepCaption("Switch any time in Settings — your history converts with it.")
        }
    }

    private func unitCard(_ option: WeightUnit, big: String, small: String) -> some View {
        let selected = unit == option
        return Button {
            withAnimation(.snappy) { unit = option }
            Haptics.selection()
        } label: {
            VStack(spacing: 6) {
                Text(big)
                    .font(.condensed(46, weight: .heavy))
                    .foregroundStyle(selected ? Color.white : Color.textMain)
                Text(small)
                    .font(.barlow(15, weight: .semibold))
                    .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.textDim)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Color.clear : Color.strokeStrong, lineWidth: 1)
            )
            .shadow(color: selected ? Color.purplePrimary.opacity(0.4) : .clear, radius: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var goalStep: some View {
        VStack(spacing: 22) {
            stepTitle("HOW MANY DAYS A WEEK?")
            Text("\(goal)")
                .font(.condensed(96, weight: .heavy))
                .foregroundStyle(Color.textMain)
                .contentTransition(.numericText())
                .brandGlow(Color.purplePrimary.opacity(0.4), radius: 16)
            HStack(spacing: 8) {
                ForEach(2...6, id: \.self) { n in
                    let selected = goal == n
                    Button {
                        withAnimation(.snappy) { goal = n }
                        Haptics.selection()
                    } label: {
                        Text("\(n)")
                            .font(.condensed(22, weight: .bold))
                            .foregroundStyle(selected ? Color.white : Color.textSoft)
                            .frame(width: 52, height: 52)
                            .background(
                                Circle().fill(selected ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.surface))
                            )
                            .overlay(Circle().stroke(selected ? Color.clear : Color.strokeStrong, lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("\(n) days a week")
                }
            }
            stepCaption("Your week fills in as you train. Hit the goal, keep the streak.")
        }
    }

    private var alertsStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 104, height: 104)
                .background(Circle().fill(Color.purplePrimary.opacity(0.14)))
            stepTitle("KNOW WHEN REST IS UP")
            stepCaption("A sound and a banner when your rest timer ends — even with your phone locked or music playing.")
        }
    }

    private var readyStep: some View {
        VStack(spacing: 20) {
            RankEmblem(rank: Rank(index: 0), size: 110)
            stepTitle(Brand.onboardingReady)
            stepCaption("Finish your first workout to earn \(Brand.firstRankName). Every set after that moves you up.")
        }
    }

    private func stepTitle(_ text: String) -> some View {
        Text(text)
            .font(.condensed(34, weight: .heavy))
            .kerning(1.2)
            .foregroundStyle(Color.textMain)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func stepCaption(_ text: String) -> some View {
        Text(text)
            .font(.barlow(16))
            .lineSpacing(3)
            .foregroundStyle(Color.textDim)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 330)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Behaviour

    private func go(to next: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            step = min(max(0, next), lastStep)
        }
        Haptics.tap()
    }

    private func finish(startWorkout: Bool) {
        if let profile = profiles.first {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { profile.name = trimmed }
            profile.weeklyGoal = goal
        }
        Prefs.shared.setUnit(unit)
        Prefs.shared.setOnboarded(true)
        try? context.save()
        Haptics.success()
        onFinish()

        guard startWorkout, app.activeWorkout == nil else { return }
        let w = WorkoutBuilder.start(routine: nil, context: context, history: workouts)
        app.activeWorkout = w
        app.showSummary = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            app.workoutPresented = true
        }
    }
}
