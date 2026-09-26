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

    private var profile: Profile? { profiles.first }

    var body: some View {
        let done = workouts.filter { $0.endedAt != nil }
        return NavigationStack {
            Group {
                if done.isEmpty && routines.isEmpty {
                    EmptyHomeView()
                } else {
                    dashboard(done)
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Dashboard

    private func dashboard(_ done: [Workout]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(done)
                weekCard(done)
                upNextSection(done)
                quickActions
                recentRecords(done)
                supplementsCard
            }
            .padding(.horizontal, Layout.screenPad)
            .padding(.top, 8)
            .padding(.bottom, Layout.tabBarClearance)
        }
    }

    // MARK: Header

    private func header(_ done: [Workout]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    logoMark
                    Text(Brand.wordmark)
                        .font(.condensed(Brand.wordmarkSize, weight: .heavy))
                        .kerning(Brand.wordmarkKerning)
                        .foregroundStyle(Color.textMain)
                }
                Spacer()
                StreakPill(days: Stats.streak(done))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.condensed(30, weight: .heavy))
                    .kerning(0.5)
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(greetingSubline(done))
                    .font(.barlow(15))
                    .foregroundStyle(Color.textDim)
            }
        }
    }

    private var logoMark: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.surface)
            .frame(width: 32, height: 32)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1))
            .overlay(LogoBars())
            .shadow(color: Color.purplePrimary.opacity(0.25), radius: 7)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part: String
        switch hour {
        case 5..<12: part = "GOOD MORNING"
        case 12..<17: part = "GOOD AFTERNOON"
        default: part = "GOOD EVENING"
        }
        let name = (profile?.name ?? "").trimmingCharacters(in: .whitespaces)
        if name.isEmpty || name.uppercased() == "ATHLETE" { return part }
        return "\(part), \(name.uppercased())"
    }

    private func greetingSubline(_ done: [Workout]) -> String {
        if done.contains(where: { Calendar.current.isDateInToday($0.startedAt) }) {
            return "Today's session is in the books."
        }
        let week = Stats.workouts(done, in: Stats.weekInterval(containing: Date())).count
        let goal = profile?.weeklyGoal ?? 5
        if week >= goal { return "Weekly goal hit. Anything more is a bonus." }
        let left = goal - week
        if week == 0 { return "A fresh week — \(goal) session\(goal == 1 ? "" : "s") to go." }
        return "\(left) more session\(left == 1 ? "" : "s") to hit your weekly goal."
    }

    // MARK: Week

    private static let weekdayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    private func weekCard(_ done: [Workout]) -> some View {
        let cal = Calendar.current
        let week = Stats.weekInterval(containing: Date())
        let thisWeek = Stats.workouts(done, in: week)
        let goal = profile?.weeklyGoal ?? 5
        let trainedDays = Set(thisWeek.map { cal.startOfDay(for: $0.startedAt) })
        let volume = thisWeek.reduce(0.0) { $0 + Stats.volume($1) }
        let lastWeekStart = cal.date(byAdding: .day, value: -7, to: week.start) ?? week.start
        let lastWeekVolume = Stats.workouts(done, in: DateInterval(start: lastWeekStart, duration: 7 * 86400))
            .reduce(0.0) { $0 + Stats.volume($1) }
        let prs = thisWeek.reduce(0) { $0 + Stats.prSets($1).count }
        let sets = thisWeek.reduce(0) { $0 + Stats.completedSetCount($1) }

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("This week")
                Spacer()
                Text("\(thisWeek.count) of \(goal) workouts")
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(thisWeek.count >= goal ? Color.successGreen : Color.textSoft)
            }

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let day = cal.date(byAdding: .day, value: i, to: week.start) ?? week.start
                    dayDot(day: day, letter: HomeView.weekdayLetters[i], trained: trainedDays.contains(cal.startOfDay(for: day)))
                        .frame(maxWidth: .infinity)
                }
            }

            Divider().overlay(Color.hairline)

            HStack(alignment: .top, spacing: 0) {
                weekMetric(Fmt.volumeK(volume), unit: Fmt.unitLabel, label: "Volume", delta: delta(volume, lastWeekVolume))
                weekMetric("\(sets)", unit: "", label: "Sets", delta: nil)
                weekMetric("\(prs)", unit: "", label: Brand.recordsTile, delta: nil, glow: prs > 0)
            }
        }
        .padding(16)
        .card(20)
    }

    private func dayDot(day: Date, letter: String, trained: Bool) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(day)
        let isFuture = day > Date() && !isToday
        let number = "\(cal.component(.day, from: day))"
        return VStack(spacing: 6) {
            Text(letter)
                .font(.barlow(11.5, weight: .bold))
                .foregroundStyle(isToday ? Color.purpleBright : Color.textFaint)
            ZStack {
                if trained {
                    Circle().fill(Color.accentGradient)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                } else if isToday {
                    Circle().stroke(Color.purpleBright, lineWidth: 2)
                    Text(number)
                        .font(.condensed(15, weight: .bold))
                        .foregroundStyle(Color.textMain)
                } else {
                    Circle().fill(isFuture ? Color.clear : Color.surface2)
                    Circle().stroke(Color.hairline, lineWidth: 1)
                    Text(number)
                        .font(.condensed(15, weight: .semibold))
                        .foregroundStyle(isFuture ? Color.textFaint : Color.textDim)
                }
            }
            .frame(width: 36, height: 36)
            .shadow(color: trained ? Color.purplePrimary.opacity(0.35) : .clear, radius: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Fmt.dayLabel(day))\(trained ? ", trained" : "")")
    }

    private func delta(_ now: Double, _ then: Double) -> (text: String, up: Bool)? {
        guard then > 0 else { return nil }
        let pct = ((now - then) / then * 100).roundedInt
        return pct >= 0 ? (text: "↑ \(pct)% vs last wk", up: true) : (text: "↓ \(-pct)% vs last wk", up: false)
    }

    private func weekMetric(_ value: String, unit: String, label: String, delta: (text: String, up: Bool)?, glow: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.condensed(27, weight: .bold))
                    .foregroundStyle(glow ? Color.glow : Color.textMain)
                    .brandGlow(glow ? Color.glow.opacity(0.4) : .clear, radius: 6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.condensed(15, weight: .bold))
                        .foregroundStyle(Color.textDim)
                }
            }
            Text(label.uppercased())
                .font(.barlow(11, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.textDim)
            if let delta {
                Text(delta.text)
                    .font(.barlow(12, weight: .semibold))
                    .foregroundStyle(delta.up ? Color.successGreen : Color.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Up next

    @ViewBuilder
    private func upNextSection(_ done: [Workout]) -> some View {
        if let info = upNextInfo(done) {
            UpNextCard(
                routine: info.routine,
                headerLabel: info.label,
                lastSession: done.first { $0.title == info.routine.name },
                onStart: { startRoutine(info.routine) },
                onSwitch: { app.showStartSheet = true }
            )
        } else {
            buildSplitCard
        }
    }

    /// With a split: the day after the last one done. Without one: the
    /// routine that has waited longest.
    private func upNextInfo(_ done: [Workout]) -> (routine: Routine, label: String)? {
        let scheduled = routines
            .filter { $0.scheduleIndex != nil }
            .sorted { ($0.scheduleIndex ?? 0) < ($1.scheduleIndex ?? 0) }
        if !scheduled.isEmpty {
            let names = Set(scheduled.map { $0.name })
            var nextIndex = 0
            if let lastMatch = done.first(where: { names.contains($0.title) }),
               let idx = scheduled.firstIndex(where: { $0.name == lastMatch.title }) {
                nextIndex = (idx + 1) % scheduled.count
            }
            return (scheduled[nextIndex], "UP NEXT · DAY \(nextIndex + 1) OF \(scheduled.count)")
        }
        let suggested = routines.min { a, b in
            let la = done.first { $0.title == a.name }?.startedAt ?? .distantPast
            let lb = done.first { $0.title == b.name }?.startedAt ?? .distantPast
            if la == lb { return a.orderIndex < b.orderIndex }
            return la < lb
        }
        if let suggested { return (suggested, "SUGGESTED NEXT") }
        return nil
    }

    private var buildSplitCard: some View {
        NavigationLink {
            RoutinesView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("BUILD YOUR SPLIT")
                    .font(.condensed(26, weight: .heavy))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Text("Save your routines as Day 1, Day 2… and \(Brand.plainName) always knows what's next. Or adopt a proven program in one tap.")
                    .font(.barlow(15))
                    .lineSpacing(3)
                    .foregroundStyle(Color.textDim)
                HStack(spacing: 6) {
                    Text("Set it up")
                        .font(.barlow(15, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.purpleBright)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .card(20, border: Color.purplePrimary.opacity(0.3))
        }
        .buttonStyle(.pressable)
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                startEmpty()
            } label: {
                quickTile(icon: "plus", title: "Empty workout", subtitle: "Build as you go")
            }
            .buttonStyle(.pressable)

            NavigationLink {
                RoutinesView()
            } label: {
                quickTile(
                    icon: "list.bullet.rectangle",
                    title: "Routines",
                    subtitle: routines.isEmpty ? "Programs & splits" : "\(routines.count) saved"
                )
            }
            .buttonStyle(.pressable)
        }
    }

    private func quickTile(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.purplePrimary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.barlow(16, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                Text(subtitle)
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card(18)
    }

    // MARK: Records

    @ViewBuilder
    private func recentRecords(_ done: [Workout]) -> some View {
        let prs = recentPRs(done)
        if !prs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(Brand.recordsTitle)
                VStack(spacing: 0) {
                    ForEach(Array(prs.enumerated()), id: \.offset) { i, pr in
                        NavigationLink {
                            ExerciseDetailView(exerciseName: pr.name)
                        } label: {
                            prRow(pr)
                        }
                        .buttonStyle(.plain)
                        if i < prs.count - 1 {
                            Divider().overlay(Color.hairline).padding(.leading, 64)
                        }
                    }
                }
                .card()
            }
        }
    }

    private func recentPRs(_ done: [Workout]) -> [(name: String, set: SetEntry, date: Date)] {
        var out: [(name: String, set: SetEntry, date: Date)] = []
        for w in done {
            for pr in Stats.prSets(w) {
                out.append((pr.name, pr.set, w.startedAt))
                if out.count == 3 { return out }
            }
        }
        return out
    }

    private func prRow(_ pr: (name: String, set: SetEntry, date: Date)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.glow)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.glow.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.name)
                    .font(.barlow(16, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
                Text(prDetail(pr.set, date: pr.date))
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
            }
            Spacer(minLength: 6)
            Text(pr.set.weight > 0 ? "\(Fmt.weight(pr.set.weight)) × \(pr.set.reps)" : "\(pr.set.reps) reps")
                .font(.condensed(21, weight: .bold))
                .foregroundStyle(Color.textMain)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textFaint)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private func prDetail(_ set: SetEntry, date: Date) -> String {
        if set.weight > 0 {
            return "Est. 1RM \(Fmt.whole(Stats.e1RM(set.weight, set.reps))) \(Fmt.unitLabel) · \(Fmt.relative(date))"
        }
        return "Rep record · \(Fmt.relative(date))"
    }

    // MARK: Supplements

    @ViewBuilder
    private var supplementsCard: some View {
        if !supplements.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel("Supplements today")
                    Spacer()
                    NavigationLink {
                        SupplementsView()
                    } label: {
                        Text("Manage")
                            .font(.barlow(13.5, weight: .semibold))
                            .foregroundStyle(Color.purpleBright)
                            .frame(minHeight: Layout.minTap)
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 0) {
                    ForEach(Array(supplements.prefix(4).enumerated()), id: \.offset) { i, supplement in
                        supplementRow(supplement)
                        if i < min(supplements.count, 4) - 1 {
                            Divider().overlay(Color.hairlineSoft).padding(.leading, 16)
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
        let taken = total > 0
        return HStack(spacing: 12) {
            Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(taken ? Color.successGreen : Color.textFaint)
            VStack(alignment: .leading, spacing: 1) {
                Text(supplement.name)
                    .font(.barlow(16, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                Text(taken ? "\(Fmt.num(total)) \(supplement.unit) today" : "Not yet today")
                    .font(.barlow(13))
                    .foregroundStyle(taken ? Color.textSoft : Color.textDim)
            }
            Spacer()
            Button {
                context.insert(SupplementLog(supplement: supplement))
                try? context.save()
                Haptics.medium()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(Fmt.num(supplement.serving)) \(supplement.unit)")
                        .font(.barlow(13.5, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(Capsule().fill(Color.accentGradient))
                .frame(minHeight: Layout.minTap)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Log \(supplement.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: Starting

    private func startRoutine(_ routine: Routine) {
        guard app.activeWorkout == nil else {
            app.workoutPresented = true
            return
        }
        let w = WorkoutBuilder.start(routine: routine, context: context, history: workouts)
        app.activeWorkout = w
        app.showSummary = false
        app.workoutPresented = true
        Haptics.medium()
    }

    private func startEmpty() {
        guard app.activeWorkout == nil else {
            app.workoutPresented = true
            return
        }
        let w = WorkoutBuilder.start(routine: nil, context: context, history: workouts)
        app.activeWorkout = w
        app.showSummary = false
        app.workoutPresented = true
        Haptics.medium()
    }
}

// MARK: - Up next card

struct UpNextCard: View {
    let routine: Routine
    let headerLabel: String
    let lastSession: Workout?
    let onStart: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerLabel)
                        .font(.barlow(12, weight: .bold))
                        .kerning(1.8)
                        .foregroundStyle(Color.purpleBright)
                    Text(routine.name.uppercased())
                        .font(.condensed(34, weight: .heavy))
                        .kerning(1)
                        .foregroundStyle(Color.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(subtitle)
                        .font(.barlow(14))
                        .foregroundStyle(Color.textDim)
                }
                Spacer(minLength: 8)
                Button(action: onSwitch) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                        Text("Switch")
                            .font(.barlow(13.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.purpleBright)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Capsule().fill(Color.purplePrimary.opacity(0.12)))
                    .overlay(Capsule().stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1))
                    .frame(minHeight: Layout.minTap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }

            let names = routine.sortedItems.prefix(3).map { $0.displayName }
            if !names.isEmpty {
                HStack(spacing: 6) {
                    ForEach(names, id: \.self) { TagChip(text: $0) }
                    if routine.items.count > 3 {
                        TagChip(text: "+\(routine.items.count - 3) more", dim: true)
                    }
                }
                .padding(.top, 14)
            }

            if let lastSession {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Last time \(Fmt.relative(lastSession.startedAt).lowercased()) · \(Fmt.volumeK(Stats.volume(lastSession))) \(Fmt.unitLabel) · \(Fmt.duration(lastSession.duration))")
                        .font(.barlow(13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Color.textDim)
                .padding(.top, 12)
            }

            GradientCTA("START WORKOUT", systemIcon: "play.fill", action: onStart)
                .padding(.top, 16)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color.surfaceRaised, .surface], startPoint: .top, endPoint: .bottom))
                .shadow(color: Brand.isLight ? Color.black.opacity(0.06) : .clear, radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
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
        let count = routine.items.count
        var parts = ["\(count) exercise\(count == 1 ? "" : "s")"]
        if let lastSession {
            parts.append("~\(Fmt.duration(lastSession.duration))")
        } else {
            let seconds = routine.items.reduce(0) { $0 + $1.plannedSets * ($1.restSeconds + 45) }
            if seconds > 0 { parts.append("~\(Fmt.duration(Double(seconds)))") }
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
                colors: [Color.purplePrimary.opacity(0.16), .clear],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 0, endRadius: 260
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.surface)
                        .frame(width: 32, height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1))
                        .overlay(LogoBars())
                    Text(Brand.wordmark)
                        .font(.condensed(Brand.wordmarkSize, weight: .heavy))
                        .kerning(Brand.wordmarkKerning)
                        .foregroundStyle(Color.textMain)
                }
                .padding(.horizontal, Layout.screenPad)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 0) {
                    Hexagon()
                        .fill(LinearGradient(colors: [.surface2, .surface], startPoint: .top, endPoint: .bottom))
                        .frame(width: 108, height: 118)
                        .overlay(Hexagon().fill(Color.surface).padding(2.5))
                        .overlay(Hexagon().stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1.5))
                        .overlay(LogoBars(barWidth: 7, barHeight: 28, glowRadius: 8))

                    Text(Brand.emptyStateTitle)
                        .font(.condensed(32, weight: .heavy))
                        .kerning(2.5)
                        .foregroundStyle(Color.textMain)
                        .multilineTextAlignment(.center)
                        .padding(.top, 26)

                    Text(Brand.emptyStateMessage)
                        .font(.barlow(16))
                        .lineSpacing(4)
                        .foregroundStyle(Color.textDim)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 310)
                        .padding(.top, 10)

                    GradientCTA("START YOUR FIRST WORKOUT", systemIcon: "play.fill") {
                        guard app.activeWorkout == nil else {
                            app.workoutPresented = true
                            return
                        }
                        let w = WorkoutBuilder.start(routine: nil, context: context, history: workouts)
                        app.activeWorkout = w
                        app.showSummary = false
                        app.workoutPresented = true
                        Haptics.medium()
                    }
                    .frame(maxWidth: 330)
                    .padding(.top, 30)

                    NavigationLink {
                        RoutinesView()
                    } label: {
                        Text("Browse programs")
                            .font(.barlow(16, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                            .frame(maxWidth: 330)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.surface))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.strokeStrong, lineWidth: 1))
                    }
                    .buttonStyle(.pressable)
                    .padding(.top, 10)

                    HStack(spacing: 10) {
                        Hexagon()
                            .fill(Color.surface3)
                            .frame(width: 26, height: 28)
                            .overlay(
                                Text("I")
                                    .font(.condensed(13, weight: .bold))
                                    .foregroundStyle(Color.textDim)
                            )
                        Text("Finish one workout to earn ")
                            .font(.barlow(13.5))
                            .foregroundStyle(Color.textDim)
                        + Text(Brand.firstRankName)
                            .font(.barlow(13.5, weight: .bold))
                            .foregroundStyle(Color.textSoft)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .card(14)
                    .padding(.top, 34)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Layout.screenPad)

                Spacer()
                Spacer()
            }
        }
    }
}
