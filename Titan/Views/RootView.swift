import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context

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
                }
                TitanTabBar()
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
        }
    }
}

struct WorkoutFlowView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            if let workout = app.activeWorkout {
                if app.showSummary {
                    WorkoutCompleteView(workout: workout)
                } else {
                    ActiveWorkoutView(workout: workout)
                }
            } else {
                Color.bg.ignoresSafeArea()
            }
        }
    }
}

// MARK: - Tab bar

struct TitanTabBar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HStack(alignment: .top) {
            tabButton(.home, icon: "house", label: "Home")
            tabButton(.history, icon: "clock", label: "History")
            centerButton
            tabButton(.progress, icon: "chart.bar.fill", label: "Progress")
            tabButton(.profile, icon: "person", label: "Profile")
        }
        .padding(.horizontal, 20)
        .padding(.top, 9)
        .frame(height: 84, alignment: .top)
        .background(
            Color(hex: 0x0C0C13).opacity(0.96)
                .overlay(Rectangle().fill(Color.purplePrimary.opacity(0.16)).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: Tab, icon: String, label: String) -> some View {
        let selected = app.tab == tab
        return Button {
            app.tab = tab
            Haptics.tap()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
                Text(label)
                    .font(.barlow(10, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? Color.purpleBright : Color.textFaint)
            .frame(width: 56)
        }
        .buttonStyle(.plain)
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
            RoundedRectangle(cornerRadius: 17)
                .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.purplePrimary.opacity(0.45), radius: 13)
                .shadow(color: .black.opacity(0.55), radius: 11, y: 10)
        }
        .buttonStyle(.plain)
        .offset(y: -26)
    }
}

// MARK: - Resume banner

struct ResumeBar: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Button {
            app.workoutPresented = true
        } label: {
            HStack {
                Circle()
                    .fill(Color.glow)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.glow.opacity(0.9), radius: 4)
                Text(app.activeWorkout?.hasBegun == false ? "FINISH SETUP" : "RESUME WORKOUT")
                    .font(.condensed(15, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(.white)
                Spacer()
                if let w = app.activeWorkout, w.hasBegun {
                    Text(w.startedAt, style: .timer)
                        .font(.condensed(17, weight: .bold))
                        .foregroundStyle(.white)
                }
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .leading, endPoint: .trailing))
            )
            .shadow(color: Color.purplePrimary.opacity(0.35), radius: 10)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Start workout sheet

struct StartWorkoutSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(14, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                Spacer()
                Text("START WORKOUT")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Color.clear.frame(width: 48, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    GradientCTA("CREATE YOUR OWN", systemIcon: "plus") {
                        start(nil)
                    }
                    Text("Build it as you go — pick your exercises, log your sets.")
                        .font(.barlow(12))
                        .foregroundStyle(Color.textDim)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    SectionLabel("Or use a template")
                        .padding(.top, 12)

                    ForEach(routines) { routine in
                        Button {
                            start(routine)
                        } label: {
                            routineRow(routine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(Color(hex: 0x10101B).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func routineRow(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(routine.name)
                        .font(.condensed(22, weight: .bold))
                        .foregroundStyle(Color.textMain)
                    Text(subtitle(routine))
                        .font(.barlow(11.5))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                    )
                    .shadow(color: Color.purplePrimary.opacity(0.35), radius: 7)
            }
            let names = routine.sortedItems.prefix(4).map { $0.displayName }
            if !names.isEmpty {
                HStack(spacing: 5) {
                    ForEach(names, id: \.self) { TagChip(text: $0) }
                    if routine.items.count > 4 {
                        TagChip(text: "+\(routine.items.count - 4)", dim: true)
                    }
                }
                .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func subtitle(_ routine: Routine) -> String {
        let count = routine.items.count
        if let last = workouts.first(where: { $0.title == routine.name && $0.endedAt != nil }) {
            return "\(count) exercises · last \(Fmt.shortDate(last.startedAt))"
        }
        return "\(count) exercises"
    }

    private func start(_ routine: Routine?) {
        let w = WorkoutBuilder.start(routine: routine, context: context, history: workouts)
        app.activeWorkout = w
        app.showSummary = false
        dismiss()
        app.workoutPresented = true
        Haptics.medium()
    }
}
