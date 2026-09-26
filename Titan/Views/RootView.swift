import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

    @State private var showOnboarding = false

    var body: some View {
        @Bindable var app = app
        ZStack(alignment: .bottom) {
            Group {
                switch app.tab {
                case .home: HomeView()
                case .history: HistoryView()
                case .progress: ProgressTabView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                if app.activeWorkout != nil && !app.workoutPresented {
                    ResumeBar()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                TitanTabBar()
            }

            if showOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) { showOnboarding = false }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .sheet(isPresented: $app.showStartSheet) {
            StartWorkoutSheet()
        }
        .fullScreenCover(isPresented: $app.workoutPresented) {
            WorkoutFlowView()
        }
        .task {
            SeedData.seedIfNeeded(context)
            restoreUnfinishedWorkouts()
            decideOnboarding()
        }
        // Wakes exactly when rest ends — no polling, and it keeps running while
        // the workout screen is minimized.
        .task(id: app.restEndsAt) {
            guard let end = app.restEndsAt else { return }
            let wait = end.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            guard !Task.isCancelled, app.restEndsAt == end else { return }
            withAnimation(.snappy) { app.restFinished() }
            Haptics.restDone()
        }
    }

    /// A workout left running when the app was killed comes back as the active
    /// workout; anything older is closed out (or deleted if nothing was logged).
    private func restoreUnfinishedWorkouts() {
        guard app.activeWorkout == nil else { return }
        let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        let all = (try? context.fetch(descriptor)) ?? []
        let open = all.filter { $0.endedAt == nil }
        guard !open.isEmpty else { return }

        for (i, w) in open.enumerated() {
            let stale = Date().timeIntervalSince(w.startedAt) > 12 * 3600
            if i == 0 && !stale {
                app.activeWorkout = w
            } else {
                WorkoutBuilder.closeStale(w, context: context)
            }
        }
        try? context.save()
    }

    private func decideOnboarding() {
        let prefs = Prefs.shared
        guard !prefs.hasOnboarded else { return }
        let count = (try? context.fetchCount(FetchDescriptor<Workout>())) ?? 0
        if count > 0 {
            // Someone updating from v1.0 already knows their way around.
            prefs.setOnboarded(true)
        } else {
            showOnboarding = true
        }
    }
}

struct WorkoutFlowView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            Group {
                if let workout = app.activeWorkout {
                    if app.showSummary {
                        WorkoutCompleteView(workout: workout)
                            .transition(.opacity)
                    } else {
                        ActiveWorkoutView(workout: workout)
                    }
                } else {
                    Color.bg.ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Tab bar

struct TitanTabBar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tabButton(.home, icon: "house", selectedIcon: "house.fill", label: "Home")
            tabButton(.history, icon: "clock", selectedIcon: "clock.fill", label: "History")
            centerButton
                .frame(maxWidth: .infinity)
            tabButton(.progress, icon: "chart.bar", selectedIcon: "chart.bar.fill", label: "Progress")
            tabButton(.profile, icon: "person", selectedIcon: "person.fill", label: "Profile")
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .frame(height: 84, alignment: .top)
        .background(
            Color.tabBarBg.opacity(0.97)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.purplePrimary.opacity(0.16)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: Tab, icon: String, selectedIcon: String, label: String) -> some View {
        let selected = app.tab == tab
        return Button {
            if app.tab != tab {
                app.tab = tab
                Haptics.selection()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selected ? selectedIcon : icon)
                    .font(.system(size: 21, weight: selected ? .semibold : .regular))
                    .frame(height: 24)
                Text(label)
                    .font(.barlow(11, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? Color.purpleBright : Color.textFaint)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var centerButton: some View {
        Button {
            Haptics.medium()
            if app.activeWorkout != nil {
                app.workoutPresented = true
            } else {
                app.showStartSheet = true
            }
        } label: {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentGradient)
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: app.activeWorkout != nil ? "bolt.fill" : "dumbbell.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.purplePrimary.opacity(0.45), radius: 13)
                .shadow(color: .black.opacity(Brand.isLight ? 0.12 : 0.55), radius: 11, y: 10)
        }
        .buttonStyle(.pressable)
        .offset(y: -26)
        .accessibilityLabel(app.activeWorkout != nil ? "Open current workout" : "Start a workout")
    }
}

// MARK: - Resume banner

struct ResumeBar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Button {
            app.workoutPresented = true
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: .white.opacity(0.9), radius: 4)
                VStack(alignment: .leading, spacing: 0) {
                    Text(app.activeWorkout?.hasBegun == false ? "FINISH SETUP" : "RESUME WORKOUT")
                        .font(.condensed(16, weight: .bold))
                        .kerning(1.8)
                    if let w = app.activeWorkout, w.hasBegun {
                        let done = Stats.completedSetCount(w)
                        let total = Stats.totalSetCount(w)
                        Text("\(w.title) · \(done)/\(total) sets")
                            .font(.barlow(12, weight: .medium))
                            .opacity(0.85)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                if let end = app.restEndsAt {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 12, weight: .bold))
                        Text(timerInterval: Date()...max(Date(), end), countsDown: true)
                            .font(.condensed(18, weight: .bold))
                            .monospacedDigit()
                    }
                } else if let w = app.activeWorkout, w.hasBegun {
                    Text(w.startedAt, style: .timer)
                        .font(.condensed(18, weight: .bold))
                        .monospacedDigit()
                }
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: Color.purplePrimary.opacity(0.35), radius: 10)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Start workout sheet

struct StartWorkoutSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }

    private var splitNext: (routine: Routine, day: Int, count: Int)? {
        let scheduled = routines
            .filter { $0.scheduleIndex != nil }
            .sorted { ($0.scheduleIndex ?? 0) < ($1.scheduleIndex ?? 0) }
        guard !scheduled.isEmpty else { return nil }
        let names = Set(scheduled.map { $0.name })
        var next = 0
        if let last = finished.first(where: { names.contains($0.title) }),
           let idx = scheduled.firstIndex(where: { $0.name == last.title }) {
            next = (idx + 1) % scheduled.count
        }
        return (scheduled[next], next + 1, scheduled.count)
    }

    var body: some View {
        let split = splitNext
        let others = routines.filter { $0 !== split?.routine }
        return VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(16, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 70, alignment: .leading)
                Spacer()
                Text("START WORKOUT")
                    .font(.condensed(20, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Color.clear.frame(width: 70, height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GradientCTA("EMPTY WORKOUT", systemIcon: "plus") {
                        start(nil)
                    }
                    Text("Build it as you go — pick exercises, log sets, done.")
                        .font(.barlow(13.5))
                        .foregroundStyle(Color.textDim)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    if let next = split {
                        SectionLabel("Up next in your split")
                            .padding(.top, 14)
                        Button {
                            start(next.routine)
                        } label: {
                            routineRow(next.routine, badge: "DAY \(next.day) OF \(next.count)", highlighted: true)
                        }
                        .buttonStyle(.pressable)
                    }

                    if let last = finished.first {
                        SectionLabel("Do it again")
                            .padding(.top, 14)
                        Button {
                            repeatWorkout(last)
                        } label: {
                            repeatRow(last)
                        }
                        .buttonStyle(.pressable)
                    }

                    if !others.isEmpty {
                        SectionLabel("Your routines")
                            .padding(.top, 14)
                        ForEach(others) { routine in
                            Button {
                                start(routine)
                            } label: {
                                routineRow(routine, badge: nil, highlighted: false)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .background(Color.sheetBg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func routineRow(_ routine: Routine, badge: String?, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    if let badge {
                        Text(badge)
                            .font(.barlow(11.5, weight: .bold))
                            .kerning(1.6)
                            .foregroundStyle(Color.purpleBright)
                    }
                    Text(routine.name)
                        .font(.condensed(23, weight: .bold))
                        .foregroundStyle(Color.textMain)
                        .lineLimit(1)
                    Text(subtitle(routine))
                        .font(.barlow(13))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.accentGradient))
                    .shadow(color: Color.purplePrimary.opacity(0.35), radius: 7)
            }
            let names = routine.sortedItems.prefix(3).map { $0.displayName }
            if !names.isEmpty {
                HStack(spacing: 6) {
                    ForEach(names, id: \.self) { TagChip(text: $0) }
                    if routine.items.count > 3 {
                        TagChip(text: "+\(routine.items.count - 3)", dim: true)
                    }
                }
                .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(18, border: highlighted ? Color.purplePrimary.opacity(0.45) : .hairline)
    }

    private func repeatRow(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.purplePrimary.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.condensed(21, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
                Text("\(Fmt.relative(workout.startedAt)) · \(workout.entries.count) exercises")
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textFaint)
        }
        .padding(14)
        .card(18)
    }

    private func subtitle(_ routine: Routine) -> String {
        let count = routine.items.count
        var parts = ["\(count) exercise\(count == 1 ? "" : "s")"]
        if let last = finished.first(where: { $0.title == routine.name }) {
            parts.append("last \(Fmt.relative(last.startedAt).lowercased())")
        }
        return parts.joined(separator: " · ")
    }

    private func start(_ routine: Routine?) {
        guard app.activeWorkout == nil else {
            dismiss()
            app.workoutPresented = true
            return
        }
        let w = WorkoutBuilder.start(routine: routine, context: context, history: workouts)
        present(w)
    }

    private func repeatWorkout(_ source: Workout) {
        guard app.activeWorkout == nil else {
            dismiss()
            app.workoutPresented = true
            return
        }
        let w = WorkoutBuilder.repeatWorkout(source, context: context, history: workouts)
        present(w)
    }

    private func present(_ w: Workout) {
        app.activeWorkout = w
        app.showSummary = false
        dismiss()
        app.workoutPresented = true
        Haptics.medium()
    }
}
