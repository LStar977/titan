import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]
    @Query private var profiles: [Profile]
    @Query(sort: \Supplement.orderIndex) private var supplements: [Supplement]
    @Query(sort: \SupplementLog.date, order: .reverse) private var supLogs: [SupplementLog]

    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }

    var body: some View {
        NavigationStack {
            Group {
                if finished.isEmpty {
                    EmptyHomeView()
                } else {
                    dashboard
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Dashboard

    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                weekSection

                if let next = upNextRoutine {
                    UpNextCard(
                        routine: next,
                        dayIndex: workoutsThisWeek.count + 1,
                        goal: profile?.weeklyGoal ?? 5,
                        lastDone: lastDone(next),
                        onStart: { startRoutine(next) },
                        onSwitch: { app.showStartSheet = true }
                    )
                }

                NavigationLink {
                    RoutinesView()
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 14))
                        Text("All Routines")
                            .font(.barlow(13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textFaint)
                    }
                    .foregroundStyle(Color.textSoft)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .card(13)
                }
                .buttonStyle(.plain)

                supplementsCard

                recentPRs
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 130)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                logoMark
                Text("TITΛN")
                    .font(.condensed(21, weight: .heavy))
                    .kerning(5)
                    .foregroundStyle(Color.textMain)
            }
            Spacer()
            StreakPill(days: Stats.streak(finished))
        }
    }

    private var logoMark: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(Color.surface)
            .frame(width: 30, height: 30)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1))
            .overlay(LogoBars())
            .shadow(color: Color.purplePrimary.opacity(0.25), radius: 7)
    }

    // MARK: Week stats

    private var week: DateInterval { Stats.weekInterval(containing: Date()) }
    private var workoutsThisWeek: [Workout] { Stats.workouts(finished, in: week) }

    private var weekLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let end = week.end.addingTimeInterval(-1)
        let fd = DateFormatter()
        fd.dateFormat = "d"
        return "THIS WEEK · \(f.string(from: week.start).uppercased())–\(fd.string(from: end))"
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(weekLabel)
            HStack(spacing: 10) {
                workoutsTile
                volumeTile
                prsTile
            }
        }
    }

    private var workoutsTile: some View {
        let goal = profile?.weeklyGoal ?? 5
        let done = workoutsThisWeek.count
        return StatTile(
            label: "Workouts",
            value: "\(done)",
            unit: "/\(goal)",
            footer: AnyView(
                HStack(spacing: 3) {
                    ForEach(0..<goal, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < done ? Color.purplePrimary : Color.surface2)
                            .frame(width: 14, height: 3)
                    }
                }
                .padding(.top, 4)
            )
        )
    }

    private var volumeTile: some View {
        let vol = workoutsThisWeek.reduce(0.0) { $0 + Stats.volume($1) }
        let lastWeek = Stats.workouts(finished, in: Stats.weekInterval(containing: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()))
            .reduce(0.0) { $0 + Stats.volume($1) }
        let deltaText: String
        let deltaColor: Color
        if lastWeek > 0 {
            let pct = Int(((vol - lastWeek) / lastWeek * 100).rounded())
            deltaText = pct >= 0 ? "↑ \(pct)% vs last week" : "↓ \(-pct)% vs last week"
            deltaColor = pct >= 0 ? .successGreen : .textDim
        } else {
            deltaText = "this week"
            deltaColor = .textDim
        }
        return StatTile(
            label: "Volume",
            value: Fmt.volumeK(vol),
            unit: vol >= 1000 ? " lb" : " lb",
            footer: AnyView(
                Text(deltaText)
                    .font(.barlow(11, weight: .semibold))
                    .foregroundStyle(deltaColor)
                    .padding(.top, 4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            )
        )
    }

    private var prsTile: some View {
        let prs = workoutsThisWeek.reduce(0) { $0 + Stats.prSets($1).count }
        return StatTile(
            label: "PRs Hit",
            value: "\(prs)",
            glowing: prs > 0,
            footer: AnyView(
                Text("this week")
                    .font(.barlow(11, weight: .medium))
                    .foregroundStyle(Color.textDim)
                    .padding(.top, 4)
            )
        )
    }

    // MARK: Up next

    private var upNextRoutine: Routine? {
        routines.min { a, b in
            let la = lastDone(a) ?? .distantPast
            let lb = lastDone(b) ?? .distantPast
            if la == lb { return a.orderIndex < b.orderIndex }
            return la < lb
        }
    }

    private func lastDone(_ routine: Routine) -> Date? {
        finished.first { $0.title == routine.name }?.startedAt
    }

    private func startRoutine(_ routine: Routine) {
        let w = WorkoutBuilder.start(routine: routine, context: context, history: workouts)
        app.activeWorkout = w
        app.showSummary = false
        app.workoutPresented = true
        Haptics.medium()
    }

    // MARK: Supplements

    @ViewBuilder
    private var supplementsCard: some View {
        if !supplements.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel("Supplements Today")
                    Spacer()
                    NavigationLink {
                        SupplementsView()
                    } label: {
                        Text("See all")
                            .font(.barlow(12, weight: .semibold))
                            .foregroundStyle(Color.purpleBright)
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 0) {
                    ForEach(Array(supplements.prefix(4).enumerated()), id: \.offset) { i, supplement in
                        supplementRow(supplement)
                        if i < min(supplements.count, 4) - 1 {
                            Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 16)
                        }
                    }
                }
                .card()
            }
        }
    }

    private func supplementRow(_ supplement: Supplement) -> some View {
        let total = supLogs
            .filter { $0.name == supplement.name && Calendar.current.isDateInToday($0.date) }
            .reduce(0.0) { $0 + $1.amount }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(supplement.name)
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                Text(total > 0 ? "\(Fmt.weight(total)) \(supplement.unit) today" : "Not yet today")
                    .font(.barlow(11.5))
                    .foregroundStyle(total > 0 ? Color.purpleBright : Color.textDim)
            }
            Spacer()
            Button {
                context.insert(SupplementLog(supplement: supplement))
                try? context.save()
                Haptics.medium()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(Fmt.weight(supplement.serving)) \(supplement.unit)")
                        .font(.barlow(12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                )
                .shadow(color: Color.purplePrimary.opacity(0.3), radius: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: Recent PRs

    private var allPRs: [(name: String, set: SetEntry, date: Date)] {
        finished
            .flatMap { w in Stats.prSets(w).map { ($0.name, $0.set, w.startedAt) } }
            .sorted { ($0.2) > ($1.2) }
    }

    private var recentPRs: some View {
        let prs = Array(allPRs.prefix(3))
        return Group {
            if !prs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Recent PRs")
                    VStack(spacing: 0) {
                        ForEach(Array(prs.enumerated()), id: \.offset) { i, pr in
                            NavigationLink {
                                ExerciseDetailView(exerciseName: pr.name)
                            } label: {
                                HStack(spacing: 12) {
                                    PRBadge()
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(pr.name)
                                            .font(.barlow(14.5, weight: .semibold))
                                            .foregroundStyle(Color.textMain)
                                        Text("e1RM \(Int(Stats.e1RM(pr.set.weight, pr.set.reps))) lb · \(Fmt.shortDate(pr.date))")
                                            .font(.barlow(11.5))
                                            .foregroundStyle(Color.textDim)
                                    }
                                    Spacer()
                                    setValueLabel(pr.set)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)
                            if i < prs.count - 1 {
                                Divider().overlay(Color.hairline).padding(.leading, 16)
                            }
                        }
                    }
                    .card()
                }
            }
        }
    }

    private func setValueLabel(_ set: SetEntry) -> some View {
        HStack(spacing: 3) {
            Text(Fmt.weight(set.weight))
                .font(.condensed(22, weight: .bold))
                .foregroundStyle(Color.textMain)
            Text("lb")
                .font(.condensed(14, weight: .bold))
                .foregroundStyle(Color.textDim)
            Text("× \(set.reps)")
                .font(.condensed(22, weight: .bold))
                .foregroundStyle(Color.textMain)
        }
    }

    private var profile: Profile? { profiles.first }
}

// MARK: - Up next card

struct UpNextCard: View {
    let routine: Routine
    let dayIndex: Int
    let goal: Int
    let lastDone: Date?
    let onStart: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SUGGESTED · DAY \(min(dayIndex, goal)) OF \(goal)")
                        .font(.barlow(10, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(Color.purpleBright)
                    Text(routine.name.uppercased())
                        .font(.condensed(32, weight: .heavy))
                        .kerning(1)
                        .foregroundStyle(Color.textMain)
                    Text(subtitle)
                        .font(.barlow(12.5))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
                Button(action: onSwitch) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                        Text("Switch")
                            .font(.barlow(12, weight: .semibold))
                    }
                    .foregroundStyle(Color.purpleBright)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.purplePrimary.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            let names = routine.sortedItems.prefix(3).map { $0.displayName }
            HStack(spacing: 6) {
                ForEach(names, id: \.self) { TagChip(text: $0) }
                if routine.items.count > 3 {
                    TagChip(text: "+\(routine.items.count - 3) more", dim: true)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 16)

            GradientCTA("START WORKOUT", systemIcon: "play.fill", action: onStart)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(LinearGradient(colors: [Color(hex: 0x17172A), .surface], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [Color.purplePrimary.opacity(0.7), Color.purplePrimary.opacity(0.12), Color.purpleDeep.opacity(0.35)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.purplePrimary.opacity(0.16), radius: 15)
    }

    private var subtitle: String {
        var parts = ["\(routine.items.count) exercises"]
        if let lastDone {
            parts.append("last done \(Fmt.shortDate(lastDone))")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Empty state

struct EmptyHomeView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.purplePrimary.opacity(0.14), .clear],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 0, endRadius: 230
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.surface)
                        .frame(width: 30, height: 30)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1))
                        .overlay(LogoBars())
                    Text("TITΛN")
                        .font(.condensed(21, weight: .heavy))
                        .kerning(5)
                        .foregroundStyle(Color.textMain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 0) {
                    Hexagon()
                        .fill(LinearGradient(colors: [.surface2, .surface], startPoint: .top, endPoint: .bottom))
                        .frame(width: 104, height: 112)
                        .overlay(
                            Hexagon()
                                .fill(Color.surface)
                                .padding(2)
                        )
                        .overlay(LogoBars(barWidth: 7, barHeight: 26, glowRadius: 8))

                    Text("THE FORGE AWAITS")
                        .font(.condensed(30, weight: .heavy))
                        .kerning(3)
                        .foregroundStyle(Color.textMain)
                        .padding(.top, 26)

                    Text("No workouts logged yet. Start your first session to begin the climb from Bronze to Titan.")
                        .font(.barlow(14))
                        .lineSpacing(4)
                        .foregroundStyle(Color.textDim)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                        .padding(.top, 8)

                    GradientCTA("CREATE YOUR WORKOUT") {
                        let w = WorkoutBuilder.start(routine: nil, context: context, history: workouts)
                        app.activeWorkout = w
                        app.showSummary = false
                        app.workoutPresented = true
                        Haptics.medium()
                    }
                    .frame(maxWidth: 300)
                    .padding(.top, 28)

                    NavigationLink {
                        RoutinesView()
                    } label: {
                        Text("Browse routine templates")
                            .font(.barlow(14, weight: .semibold))
                            .foregroundStyle(Color.textSoft)
                            .frame(maxWidth: 300)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.surface))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)

                    HStack(spacing: 10) {
                        Hexagon()
                            .fill(Color.surface3)
                            .frame(width: 26, height: 28)
                            .overlay(
                                Text("I")
                                    .font(.condensed(12, weight: .bold))
                                    .foregroundStyle(Color.textDim)
                            )
                        Text("Complete 1 workout to earn ")
                            .font(.barlow(12))
                            .foregroundStyle(Color.textDim)
                        + Text("BRONZE I")
                            .font(.barlow(12, weight: .bold))
                            .foregroundStyle(Color.textSoft)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .card(12, border: Color.white.opacity(0.06))
                    .padding(.top, 34)
                }
                .frame(maxWidth: .infinity)

                Spacer()
                Spacer()
            }
        }
    }
}
