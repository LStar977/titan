import SwiftUI
import SwiftData

/// Full breakdown of a finished workout: every exercise, every set, big type.
/// Pushed from History, or presented as a sheet from an exercise's history.
/// Everything here can be corrected after the fact.
struct WorkoutDetailView: View {
    let workout: Workout
    var asSheet = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var app
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]

    @State private var editing = false
    @State private var showDelete = false
    @State private var savedRoutineName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                topBar
                titleSection
                statsRow
                if editing || !workout.notes.isEmpty {
                    notesCard
                }
                ForEach(workout.sortedEntries) { entry in
                    entryCard(entry)
                }
                if !editing {
                    footerActions
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, Layout.screenPad)
            .padding(.bottom, asSheet ? 40 : Layout.tabBarClearance)
        }
        .scrollDismissesKeyboard(.interactively)
        .background((asSheet ? Color.sheetBg : Color.bg).ignoresSafeArea())
        .interactiveDismissDisabled(editing)
        // Leaving mid-edit (another tab, swipe back) still saves properly.
        .onDisappear {
            if editing {
                commitEdits()
                editing = false
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
                    .font(.barlow(16, weight: .semibold))
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete Workout", role: .destructive) { deleteWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its sets, records and XP come off your log. This can't be undone.")
        }
        .alert("Saved as a routine", isPresented: Binding(get: { savedRoutineName != nil }, set: { if !$0 { savedRoutineName = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\"\(savedRoutineName ?? "")\" is in your routines, ready to run again.")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            if asSheet {
                Text("WORKOUT")
                    .font(.condensed(20, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
            } else {
                Button {
                    if editing { finishEditing() }
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("History")
                            .font(.barlow(16, weight: .medium))
                    }
                    .foregroundStyle(Color.purpleBright)
                    .frame(minHeight: Layout.minTap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if editing {
                Button {
                    finishEditing()
                } label: {
                    Text("Done")
                        .font(.barlow(16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Capsule().fill(Color.accentGradient))
                        .frame(minHeight: Layout.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            } else {
                Menu {
                    Button {
                        withAnimation(.snappy) { editing = true }
                    } label: {
                        Label("Edit workout", systemImage: "pencil")
                    }
                    Button {
                        repeatWorkout()
                    } label: {
                        Label("Do it again", systemImage: "arrow.clockwise")
                    }
                    Button {
                        saveRoutine()
                    } label: {
                        Label("Save as routine", systemImage: "square.and.arrow.down")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDelete = true
                    } label: {
                        Label("Delete workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textSoft)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.surface2))
                        .frame(width: Layout.minTap, height: Layout.minTap)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Workout options")
                if asSheet {
                    Button("Done") { dismiss() }
                        .font(.barlow(16, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                        .frame(minHeight: Layout.minTap)
                }
            }
        }
        .padding(.top, asSheet ? 12 : 4)
    }

    // MARK: Title & stats

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(Fmt.dayLabel(workout.startedAt).uppercased()) · \(Fmt.time(workout.startedAt))")
                .font(.barlow(12, weight: .bold))
                .kerning(1.4)
                .foregroundStyle(Color.purpleBright)
            if editing {
                TextField("Workout name", text: Binding(get: { workout.title }, set: { workout.title = $0 }))
                    .font(.condensed(32, weight: .heavy))
                    .foregroundStyle(Color.textMain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fieldFill())
            } else {
                Text(workout.title.uppercased())
                    .font(.condensed(36, weight: .heavy))
                    .kerning(1)
                    .foregroundStyle(Color.textMain)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private var statsRow: some View {
        let prs = Stats.prSets(workout).count
        return HStack(spacing: 10) {
            statTile(Fmt.duration(workout.duration), "TIME")
            statTile(Fmt.volumeK(Stats.volume(workout)), Fmt.unitLabel.uppercased())
            statTile("\(Stats.completedSetCount(workout))", "SETS")
            statTile("\(prs)", Brand.recordsTile.uppercased(), glow: prs > 0)
        }
    }

    private func statTile(_ value: String, _ label: String, glow: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.condensed(22, weight: .bold))
                .foregroundStyle(glow ? Color.glow : Color.textMain)
                .brandGlow(glow ? Color.glow.opacity(0.5) : .clear, radius: 6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.barlow(10.5, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Color.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card(14)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Notes")
            if editing {
                TextField("How did it feel?", text: Binding(get: { workout.notes }, set: { workout.notes = $0 }), axis: .vertical)
                    .font(.barlow(16))
                    .foregroundStyle(Color.textMain)
                    .lineLimit(2...6)
            } else {
                Text(workout.notes)
                    .font(.barlow(16))
                    .foregroundStyle(Color.textSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .card(16)
    }

    // MARK: Entries

    private func entryCard(_ entry: WorkoutEntry) -> some View {
        let done = entry.completedSets
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                NavigationLink {
                    ExerciseDetailView(exerciseName: entry.displayName)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.displayName)
                                .font(.condensed(23, weight: .bold))
                                .foregroundStyle(Color.textMain)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            if !editing && !asSheet {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.purpleBright)
                            }
                        }
                        if let ex = entry.exercise {
                            Text("\(ex.equipment.rawValue.uppercased()) · \(ex.muscle.rawValue.uppercased())")
                                .font(.barlow(11.5, weight: .semibold))
                                .kerning(1.3)
                                .foregroundStyle(Color.textDim)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(editing || asSheet)
                Spacer()
                if editing {
                    Button(role: .destructive) {
                        removeEntry(entry)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.dangerRed)
                            .frame(width: Layout.minTap, height: Layout.minTap)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(entry.displayName)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if !entry.notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                    Text(entry.notes)
                        .font(.barlow(14))
                        .foregroundStyle(Color.textSoft)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Rectangle().fill(Color.hairline).frame(height: 1)

            if done.isEmpty {
                Text("No sets logged")
                    .font(.barlow(14))
                    .foregroundStyle(Color.textFaint)
                    .padding(16)
            } else {
                // Keyed by the set itself, so deleting one row can't shift a
                // focused field onto its neighbour.
                ForEach(done) { set in
                    Group {
                        if editing {
                            editRow(set, in: entry)
                        } else {
                            readRow(set, in: entry)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    if set !== done.last {
                        Divider().overlay(Color.hairlineSoft).padding(.leading, 56)
                    }
                }
            }
        }
        .card(18)
    }

    private func readRow(_ set: SetEntry, in entry: WorkoutEntry) -> some View {
        HStack(spacing: 12) {
            setBadge(set, in: entry)
            if entry.isDuration {
                Text("\(set.reps)")
                    .font(.condensed(23, weight: .bold))
                    .foregroundStyle(Color.textMain)
                + Text(" min")
                    .font(.condensed(15, weight: .bold))
                    .foregroundStyle(Color.textDim)
            } else {
                Text(loadLabel(set))
                    .font(.condensed(23, weight: .bold))
                    .foregroundStyle(set.isPR ? Color.glow : Color.textMain)
                    .brandGlow(set.isPR ? Color.glow.opacity(0.5) : .clear, radius: 6)
            }
            if set.isPR {
                PRBadge(filled: true)
            }
            Spacer()
            if !entry.isDuration, Stats.setVolume(set) > 0 {
                Text("\(Fmt.volumeK(Stats.setVolume(set))) \(Fmt.unitLabel)")
                    .font(.barlow(13))
                    .foregroundStyle(Color.textFaint)
            }
        }
    }

    private func editRow(_ set: SetEntry, in entry: WorkoutEntry) -> some View {
        HStack(spacing: 8) {
            setBadge(set, in: entry)
            if !entry.isDuration {
                NumberField(value: weightBinding(set), decimals: true)
                    .font(.condensed(22, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .frame(width: 78, height: 40)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fieldFill())
                Text(Fmt.unitLabel)
                    .font(.barlow(13, weight: .semibold))
                    .foregroundStyle(Color.textDim)
                Text("×")
                    .font(.condensed(18, weight: .bold))
                    .foregroundStyle(Color.textFaint)
            }
            NumberField(value: repsBinding(set), decimals: false)
                .font(.condensed(22, weight: .bold))
                .foregroundStyle(Color.textMain)
                .frame(width: 58, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fieldFill())
            Text(entry.isDuration ? "min" : "reps")
                .font(.barlow(13, weight: .semibold))
                .foregroundStyle(Color.textDim)
            Spacer(minLength: 0)
            Button {
                removeSet(set, from: entry)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dangerRed.opacity(0.85))
                    .frame(width: 36, height: Layout.minTap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete set")
        }
    }

    private func weightBinding(_ set: SetEntry) -> Binding<Double> {
        Binding(
            get: { (Fmt.unit.fromLb(set.weight) * 100).rounded() / 100 },
            set: { set.weight = max(0, Fmt.unit.toLb($0)) }
        )
    }

    private func repsBinding(_ set: SetEntry) -> Binding<Double> {
        Binding(
            get: { Double(set.reps) },
            set: { set.reps = max(0, min(999, $0.roundedInt)) }
        )
    }

    private func loadLabel(_ set: SetEntry) -> String {
        if set.weight > 0 {
            return "\(Fmt.weight(set.weight)) \(Fmt.unitLabel) × \(set.reps)"
        }
        if set.bodyLoad > 0 {
            return "BW × \(set.reps)"
        }
        return "\(set.reps) reps"
    }

    private func setBadge(_ set: SetEntry, in entry: WorkoutEntry) -> some View {
        let label: String
        if set.type == .warmup {
            label = "W"
        } else {
            var n = 0
            for s in entry.sortedSets {
                if s.type != .warmup { n += 1 }
                if s === set { break }
            }
            label = "\(n)"
        }
        return Text(label)
            .font(.condensed(15, weight: .bold))
            .foregroundStyle(set.type == .failure ? Color.dangerRed : (set.type == .warmup ? Color.textDim : Color.textSoft))
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.surface2))
    }

    // MARK: Footer

    private var footerActions: some View {
        VStack(spacing: 10) {
            GradientCTA("DO IT AGAIN", systemIcon: "arrow.clockwise") {
                repeatWorkout()
            }
            SecondaryButton("Save as routine", systemIcon: "square.and.arrow.down") {
                saveRoutine()
            }
        }
    }

    // MARK: Actions

    private func finishEditing() {
        commitEdits()
        hideKeyboard()
        withAnimation(.snappy) { editing = false }
        Haptics.success()
    }

    /// Tidies the edited workout and re-derives records (and with them XP)
    /// for it and everything after.
    private func commitEdits() {
        let title = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { workout.title = Stats.autoTitle(workout) }
        let empty = workout.entries.filter { $0.completedSets.isEmpty }
        for e in empty {
            workout.entries.removeAll { $0 === e }
            context.delete(e)
        }
        Stats.recomputePRs(since: workout.startedAt, all: workouts)
        try? context.save()
    }

    private func removeSet(_ set: SetEntry, from entry: WorkoutEntry) {
        withAnimation(.snappy) {
            entry.sets.removeAll { $0 === set }
            context.delete(set)
        }
        Haptics.tap()
    }

    private func removeEntry(_ entry: WorkoutEntry) {
        withAnimation(.snappy) {
            workout.entries.removeAll { $0 === entry }
            context.delete(entry)
        }
        Haptics.tap()
    }

    private func repeatWorkout() {
        guard app.activeWorkout == nil else {
            if asSheet { dismiss() }
            app.workoutPresented = true
            return
        }
        let w = WorkoutBuilder.repeatWorkout(workout, context: context, history: workouts)
        if asSheet { dismiss() }
        app.activeWorkout = w
        app.showSummary = false
        app.workoutPresented = true
        Haptics.medium()
    }

    private func saveRoutine() {
        let r = WorkoutBuilder.saveAsRoutine(workout, context: context, routines: routines)
        savedRoutineName = r.name
        Haptics.success()
    }

    private func deleteWorkout() {
        let doomed = workout
        let since = workout.startedAt
        let remaining = workouts.filter { $0 !== doomed }
        let ctx = context
        dismiss()
        // Delete after the screen is gone so nothing renders a deleted object.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            ctx.delete(doomed)
            Stats.recomputePRs(since: since, all: remaining)
            try? ctx.save()
            Haptics.warning()
        }
    }
}
