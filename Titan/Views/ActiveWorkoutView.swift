import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    let workout: Workout
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]
    @Query private var profiles: [Profile]

    @State private var showPicker = false
    @State private var showPlates = false
    @State private var plateWeight: Double = 135
    @State private var showFinishConfirm = false
    @State private var showDiscardConfirm = false
    @State private var expanded: Set<ObjectIdentifier> = []
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    if workout.entries.isEmpty {
                        VStack(spacing: 8) {
                            Text("YOUR WORKOUT, YOUR RULES")
                                .font(.condensed(22, weight: .bold))
                                .kerning(2)
                                .foregroundStyle(Color.textMain)
                            Text("Add your first exercise to start logging sets.")
                                .font(.barlow(13))
                                .foregroundStyle(Color.textDim)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    ForEach(blocks) { block in
                        switch block {
                        case .single(let entry):
                            ExerciseCard(
                                entry: entry,
                                workout: workout,
                                allWorkouts: allWorkouts,
                                onCompleteSet: completeSet,
                                onPlates: { w in plateWeight = max(w, 45); showPlates = true }
                            )
                        case .superset(let group, let entries):
                            supersetBlock(group: group, entries: entries)
                        }
                    }
                    footerButtons
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .background(Color.bg.ignoresSafeArea())
        .onAppear {
            if workout.entries.isEmpty { showPicker = true }
        }
        .overlay(alignment: .bottom) {
            if !workout.hasBegun {
                startOverlay
            } else if app.restEndsAt != nil {
                RestTimerBar()
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { picked in
                for ex in picked {
                    WorkoutBuilder.addExercise(
                        ex, to: workout, context: context,
                        history: allWorkouts,
                        defaultRest: profiles.first?.defaultRestSeconds ?? 120
                    )
                }
            }
        }
        .sheet(isPresented: $showPlates) {
            PlateCalculatorView(initialTarget: plateWeight)
        }
        .confirmationDialog("Finish workout?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
            Button("Finish Workout") { finish() }
            Button("Discard Workout", role: .destructive) { discard() }
            Button("Keep Going", role: .cancel) {}
        }
        .confirmationDialog("No sets completed", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Discard Workout", role: .destructive) { discard() }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    app.workoutPresented = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.textDim)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.surface2))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 0) {
                    Text(workout.title.uppercased())
                        .font(.barlow(10, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(Color.textDim)
                    if workout.hasBegun {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(Color.glow)
                                .frame(width: 7, height: 7)
                                .shadow(color: Color.glow.opacity(0.9), radius: 4)
                                .opacity(pulse ? 0.35 : 1)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                            Text(workout.startedAt, style: .timer)
                                .font(.condensed(30, weight: .bold))
                                .kerning(1)
                                .foregroundStyle(Color.textMain)
                        }
                    } else {
                        Text("SETUP")
                            .font(.condensed(30, weight: .bold))
                            .kerning(3)
                            .foregroundStyle(Color.textFaint)
                    }
                }

                Spacer()

                if workout.hasBegun {
                    Button {
                        if Stats.completedSetCount(workout) == 0 {
                            showDiscardConfirm = true
                        } else {
                            showFinishConfirm = true
                        }
                    } label: {
                        Text("FINISH")
                            .font(.condensed(15, weight: .bold))
                            .kerning(1.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(
                                Capsule().fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                            )
                            .shadow(color: Color.purplePrimary.opacity(0.35), radius: 8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showDiscardConfirm = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textDim)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.surface2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            HStack(spacing: 14) {
                statText(Fmt.volumeK(Stats.volume(workout)), "lb volume")
                divider
                statText("\(Stats.completedSetCount(workout))", "sets")
                divider
                let prs = Stats.prSets(workout).count
                Text("\(prs) PR\(prs == 1 ? "" : "s")")
                    .font(.barlow(11.5, weight: .semibold))
                    .foregroundStyle(prs > 0 ? Color.glow : Color.textDim)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [Color(hex: 0x10101B), .bg], startPoint: .top, endPoint: .bottom)
                .overlay(Rectangle().fill(Color.hairline).frame(height: 1), alignment: .bottom)
                .ignoresSafeArea(edges: .top)
        )
        .onAppear { pulse = true }
    }

    private var divider: some View {
        Text("|")
            .font(.barlow(11.5))
            .foregroundStyle(Color(hex: 0x3A3A4E))
    }

    private func statText(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.barlow(11.5, weight: .semibold))
                .foregroundStyle(Color.textSoft)
            Text(label)
                .font(.barlow(11.5))
                .foregroundStyle(Color.textDim)
        }
    }

    // MARK: Blocks (superset grouping)

    private enum Block: Identifiable {
        case single(WorkoutEntry)
        case superset(Int, [WorkoutEntry])

        var id: String {
            switch self {
            case .single(let e): return "e-\(ObjectIdentifier(e).hashValue)"
            case .superset(let g, _): return "ss-\(g)"
            }
        }
    }

    private var blocks: [Block] {
        var out: [Block] = []
        var currentGroup: Int?
        var groupEntries: [WorkoutEntry] = []

        func flush() {
            if let g = currentGroup, !groupEntries.isEmpty {
                if groupEntries.count > 1 {
                    out.append(.superset(g, groupEntries))
                } else {
                    out.append(.single(groupEntries[0]))
                }
            }
            currentGroup = nil
            groupEntries = []
        }

        for entry in workout.sortedEntries {
            if let g = entry.supersetGroup {
                if g == currentGroup {
                    groupEntries.append(entry)
                } else {
                    flush()
                    currentGroup = g
                    groupEntries = [entry]
                }
            } else {
                flush()
                out.append(.single(entry))
            }
        }
        flush()
        return out
    }

    private func supersetBlock(group: Int, entries: [WorkoutEntry]) -> some View {
        VStack(spacing: 8) {
            ForEach(entries) { entry in
                let isOpen = expanded.contains(ObjectIdentifier(entry))
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.snappy) {
                            if isOpen { expanded.remove(ObjectIdentifier(entry)) }
                            else { expanded.insert(ObjectIdentifier(entry)) }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.displayName)
                                    .font(.condensed(17, weight: .bold))
                                    .foregroundStyle(Color.textMain)
                                Text(supersetSubtitle(entry))
                                    .font(.barlow(11))
                                    .foregroundStyle(Color.textDim)
                            }
                            Spacer()
                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.textFaint)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if isOpen {
                        ExerciseCard(
                            entry: entry,
                            workout: workout,
                            allWorkouts: allWorkouts,
                            embedded: true,
                            onCompleteSet: completeSet,
                            onPlates: { w in plateWeight = max(w, 45); showPlates = true }
                        )
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.surface))
            }
        }
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Text("SUPERSET \(supersetLetter(group))")
                .font(.barlow(9.5, weight: .bold))
                .kerning(2)
                .foregroundStyle(Color.purpleBright)
                .padding(.horizontal, 8)
                .background(Color.bg)
                .offset(x: 16, y: -7)
        }
        .padding(.top, 4)
    }

    private func supersetLetter(_ group: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        let groups = Array(Set(workout.entries.compactMap { $0.supersetGroup })).sorted()
        if let idx = groups.firstIndex(of: group), idx < letters.count { return letters[idx] }
        return "A"
    }

    private func supersetSubtitle(_ entry: WorkoutEntry) -> String {
        let done = entry.completedSets.count
        let total = entry.sets.count
        if let next = entry.sortedSets.first(where: { !$0.isCompleted }) {
            return "\(done) of \(total) sets · next: \(Fmt.weight(next.weight)) × \(next.reps)"
        }
        return "\(done) of \(total) sets · complete"
    }

    // MARK: Footer buttons

    private var footerButtons: some View {
        HStack(spacing: 10) {
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Exercise")
                        .font(.barlow(13, weight: .semibold))
                }
                .foregroundStyle(Color.purpleBright)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 13).fill(Color.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(Color.purplePrimary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
            .buttonStyle(.plain)

            Button {
                groupLastTwo()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Superset")
                        .font(.barlow(13, weight: .semibold))
                }
                .foregroundStyle(Color.textSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 13).fill(Color.surface))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    /// Groups the last two ungrouped exercises into a new superset.
    private func groupLastTwo() {
        let ungrouped = workout.sortedEntries.filter { $0.supersetGroup == nil }
        guard ungrouped.count >= 2 else { return }
        let nextGroup = (workout.entries.compactMap { $0.supersetGroup }.max() ?? 0) + 1
        let pair = ungrouped.suffix(2)
        for e in pair { e.supersetGroup = nextGroup }
        Haptics.tap()
    }

    // MARK: Begin (setup → live)

    private var startOverlay: some View {
        VStack {
            GradientCTA("START WORKOUT", systemIcon: "play.fill") {
                begin()
            }
            .opacity(workout.entries.isEmpty ? 0.4 : 1)
            .disabled(workout.entries.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [Color.bg.opacity(0), Color.bg.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func begin() {
        workout.startedAt = Date()
        workout.hasBegun = true
        Haptics.success()
    }

    // MARK: Set completion / PR detection

    private func completeSet(_ set: SetEntry, in entry: WorkoutEntry) {
        if !workout.hasBegun {
            begin()
        }
        if set.isCompleted {
            set.isCompleted = false
            set.isPR = false
            set.completedAt = nil
            return
        }
        set.isCompleted = true
        set.completedAt = Date()

        if set.type != .warmup, set.weight > 0, set.reps > 0 {
            let best = Stats.bestE1RM(exerciseName: entry.displayName, workouts: allWorkouts, excluding: set)
            if best > 0, Stats.e1RM(set.weight, set.reps) > best {
                set.isPR = true
                Haptics.pr()
            } else {
                Haptics.medium()
            }
        } else {
            Haptics.medium()
        }

        if entry.restSeconds > 0 {
            app.startRest(seconds: entry.restSeconds)
        } else {
            app.startRest(seconds: profiles.first?.defaultRestSeconds ?? 120)
        }
    }

    // MARK: Finish / discard

    private func finish() {
        workout.endedAt = Date()
        let xp = RankSystem.xp(for: workout)
        app.xpGained = xp
        if let profile = profiles.first {
            profile.xp += xp
        }
        try? context.save()
        app.stopRest()
        Haptics.success()
        app.showSummary = true
    }

    private func discard() {
        context.delete(workout)
        try? context.save()
        app.endWorkoutFlow()
    }
}

// MARK: - Exercise card

struct ExerciseCard: View {
    let entry: WorkoutEntry
    let workout: Workout
    let allWorkouts: [Workout]
    var embedded = false
    let onCompleteSet: (SetEntry, WorkoutEntry) -> Void
    let onPlates: (Double) -> Void

    @Environment(\.modelContext) private var context

    private var prevSets: [SetEntry] {
        Stats.lastSets(exerciseName: entry.displayName, workouts: allWorkouts, excluding: workout)
    }

    private var activeSet: SetEntry? {
        entry.sortedSets.first { !$0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !embedded {
                cardHeader
            }
            columnHeaders
            ForEach(entry.sortedSets) { set in
                if set === activeSet {
                    ActiveSetEditor(
                        set: set,
                        label: setLabel(set),
                        prev: prevString(set),
                        onCheck: { onCompleteSet(set, entry) }
                    )
                    .contextMenu { setMenu(set) }
                } else {
                    completedOrPendingRow(set)
                        .contextMenu { setMenu(set) }
                }
            }
            addSetButton
        }
        .padding(.horizontal, 12)
        .padding(.top, embedded ? 4 : 14)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(embedded ? Color.clear : Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(embedded ? Color.clear : Color.hairline, lineWidth: 1)
        )
    }

    private var cardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayName)
                    .font(.condensed(22, weight: .bold))
                    .foregroundStyle(Color.textMain)
                if let ex = entry.exercise {
                    Text("\(ex.equipment.rawValue.uppercased()) · \(ex.muscle.rawValue.uppercased())")
                        .font(.barlow(10.5, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textDim)
                }
            }
            Spacer()
            Menu {
                Button {
                    addWarmupSet()
                } label: {
                    Label("Add Warm-Up Set", systemImage: "thermometer.low")
                }
                Button {
                    onPlates(activeSet?.weight ?? entry.sortedSets.last?.weight ?? 135)
                } label: {
                    Label("Plate Calculator", systemImage: "circle.circle")
                }
                Button(role: .destructive) {
                    removeExercise()
                } label: {
                    Label("Remove Exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textFaint)
                    .frame(width: 34, height: 30, alignment: .trailing)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
    }

    private var columnHeaders: some View {
        HStack(spacing: 6) {
            Text("SET").frame(width: 34, alignment: .leading)
            Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
            Text("LBS").frame(width: 62)
            Text("REPS").frame(width: 52)
            Text("✓").frame(width: 44)
        }
        .font(.barlow(9.5, weight: .bold))
        .kerning(1.2)
        .foregroundStyle(Color.textFaint)
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    private func setLabel(_ set: SetEntry) -> String {
        if set.type == .warmup { return "W" }
        var n = 0
        for s in entry.sortedSets {
            if s.type != .warmup { n += 1 }
            if s === set { break }
        }
        return "\(n)"
    }

    private func prevString(_ set: SetEntry) -> String {
        let idx = entry.sortedSets.filter { $0.type != .warmup }.firstIndex { $0 === set } ?? 0
        if let p = prevSets[safe: idx] ?? prevSets.last {
            return "\(Fmt.weight(p.weight)) × \(p.reps)"
        }
        return "—"
    }

    private func completedOrPendingRow(_ set: SetEntry) -> some View {
        let pr = set.isCompleted && set.isPR
        return HStack(spacing: 6) {
            setBadge(set)
            HStack(spacing: 7) {
                Text(prevString(set))
                    .font(.barlow(12.5))
                    .foregroundStyle(pr ? Color.textDim : Color.textFaint)
                if pr {
                    PRBadge(filled: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(set.weight > 0 ? Fmt.weight(set.weight) : "—")
                .font(.condensed(19, weight: pr ? .bold : .semibold))
                .foregroundStyle(valueColor(set, pr: pr))
                .shadow(color: pr ? Color.glow.opacity(0.7) : .clear, radius: 6)
                .frame(width: 62)
            Text("\(set.reps)")
                .font(.condensed(19, weight: pr ? .bold : .semibold))
                .foregroundStyle(valueColor(set, pr: pr))
                .shadow(color: pr ? Color.glow.opacity(0.7) : .clear, radius: 6)
                .frame(width: 52)
            checkBox(set)
                .frame(width: 44)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .opacity(set.isCompleted ? 1 : 0.6)
        .background(
            Group {
                if pr {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color.purplePrimary.opacity(0.18), Color.glow.opacity(0.05)], startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.glow.opacity(0.55), lineWidth: 1))
                        .shadow(color: Color.glow.opacity(0.3), radius: 9)
                }
            }
        )
        .overlay(alignment: .top) {
            if !pr {
                Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
            }
        }
    }

    private func valueColor(_ set: SetEntry, pr: Bool) -> Color {
        if pr { return .glow }
        return set.isCompleted ? .textMain : .textFaint
    }

    private func setBadge(_ set: SetEntry) -> some View {
        let label = setLabel(set)
        return Group {
            switch set.type {
            case .failure:
                Text("F")
                    .font(.condensed(13, weight: .bold))
                    .foregroundStyle(Color.dangerRed)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.dangerRed.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dangerRed.opacity(0.4), lineWidth: 1))
            case .drop:
                Text("D")
                    .font(.condensed(13, weight: .bold))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.purplePrimary.opacity(0.14)))
            case .warmup:
                Text("W")
                    .font(.condensed(14, weight: .bold))
                    .foregroundStyle(Color.textDim)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.surface2))
            case .working:
                Text(label)
                    .font(.condensed(14, weight: .bold))
                    .foregroundStyle(set.isPR && set.isCompleted ? Color.glow : Color.textSoft)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(set.isPR && set.isCompleted ? Color.glow.opacity(0.18) : Color.surface2)
                    )
            }
        }
        .frame(width: 34, alignment: .leading)
    }

    private func checkBox(_ set: SetEntry) -> some View {
        Button {
            onCompleteSet(set, entry)
        } label: {
            Group {
                if set.isCompleted {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.successGreen.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.successGreen.opacity(0.4), lineWidth: 1))
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.successGreen)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.surface3, lineWidth: 1)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func setMenu(_ set: SetEntry) -> some View {
        Menu("Set Type") {
            Button("Working Set — a normal set") { set.type = .working }
            Button("Warm-Up — light prep, no PR check") { set.type = .warmup }
            Button("To Failure — went to max effort") { set.type = .failure }
            Button("Drop Set — stripped weight, kept going") { set.type = .drop }
        }
        Button(role: .destructive) {
            entry.sets.removeAll { $0 === set }
            context.delete(set)
        } label: {
            Label("Delete Set", systemImage: "trash")
        }
    }

    private var addSetButton: some View {
        Button {
            let last = entry.sortedSets.last
            let set = SetEntry(
                orderIndex: (entry.sets.map { $0.orderIndex }.max() ?? -1) + 1,
                weight: last?.weight ?? 0,
                reps: last?.reps ?? 8,
                type: .working
            )
            context.insert(set)
            entry.sets.append(set)
            Haptics.tap()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Add Set")
                    .font(.barlow(12.5, weight: .semibold))
            }
            .foregroundStyle(Color.purpleBright)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
        .padding(.top, 2)
    }

    private func addWarmupSet() {
        let firstWorking = entry.sortedSets.first { $0.type == .working }
        let weight = ((firstWorking?.weight ?? 90) * 0.5 / 5).rounded() * 5
        for s in entry.sets { s.orderIndex += 1 }
        let set = SetEntry(orderIndex: 0, weight: max(weight, 45), reps: 10, type: .warmup)
        context.insert(set)
        entry.sets.append(set)
    }

    private func removeExercise() {
        workout.entries.removeAll { $0 === entry }
        context.delete(entry)
    }
}

// MARK: - Active set editor

struct ActiveSetEditor: View {
    let set: SetEntry
    let label: String
    let prev: String
    let onCheck: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Text(label)
                        .font(.condensed(14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.purplePrimary))
                    Group {
                        Text("prev ")
                            .foregroundStyle(Color.textDim)
                        + Text(prev)
                            .font(.barlow(11, weight: .semibold))
                            .foregroundStyle(Color.textSoft)
                        + Text(" · tap ✓ to log")
                            .foregroundStyle(Color.textDim)
                    }
                    .font(.barlow(11))
                    .lineLimit(1)
                }
                Spacer()
                typeMenu
            }

            HStack(spacing: 8) {
                valueBox(unit: "LBS", minus: { set.weight = max(0, set.weight - 5); Haptics.tap() },
                         plus: { set.weight += 5; Haptics.tap() }) {
                    TextField("0", value: Binding(
                        get: { set.weight },
                        set: { set.weight = max(0, min(2000, $0)) }
                    ), format: .number)
                    .keyboardType(.decimalPad)
                }
                valueBox(unit: "REPS", minus: { set.reps = max(0, set.reps - 1); Haptics.tap() },
                         plus: { set.reps += 1; Haptics.tap() }) {
                    TextField("0", value: Binding(
                        get: { set.reps },
                        set: { set.reps = max(0, min(200, $0)) }
                    ), format: .number)
                    .keyboardType(.numberPad)
                }
                Button {
                    hideKeyboard()
                    onCheck()
                } label: {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: Color.purplePrimary.opacity(0.4), radius: 9)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.surface2))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.purplePrimary.opacity(0.3), lineWidth: 1))
        .padding(.vertical, 4)
    }

    private var typeTitle: String {
        switch set.type {
        case .working: return "WORKING"
        case .warmup: return "WARM-UP"
        case .failure: return "FAILURE"
        case .drop: return "DROP SET"
        }
    }

    /// Optional set tag with plain-English explanations. Most sets stay "Working".
    private var typeMenu: some View {
        Menu {
            Button {
                set.type = .working
            } label: {
                Label("Working Set — a normal set", systemImage: "dumbbell")
            }
            Button {
                set.type = .warmup
            } label: {
                Label("Warm-Up — light prep, no PR check", systemImage: "thermometer.low")
            }
            Button {
                set.type = .failure
            } label: {
                Label("To Failure — went to max effort", systemImage: "flame")
            }
            Button {
                set.type = .drop
            } label: {
                Label("Drop Set — stripped weight, kept going", systemImage: "arrow.down.right")
            }
        } label: {
            HStack(spacing: 4) {
                Text(typeTitle)
                    .font(.barlow(9, weight: .bold))
                    .kerning(0.8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundStyle(set.type == .working ? Color.textDim : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(set.type == .working ? Color.clear : Color.purplePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(set.type == .working ? Color.surface3 : Color.clear, lineWidth: 1)
            )
        }
    }

    private func valueBox<Content: View>(
        unit: String,
        minus: @escaping () -> Void,
        plus: @escaping () -> Void,
        @ViewBuilder field: () -> Content
    ) -> some View {
        HStack(spacing: 4) {
            stepButton("minus", action: minus)
            VStack(spacing: 0) {
                field()
                    .font(.condensed(26, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
                Text(unit)
                    .font(.barlow(8.5, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(Color.textFaint)
            }
            .frame(maxWidth: .infinity)
            stepButton("plus", action: plus)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 11).fill(Color.surface))
        .frame(maxWidth: .infinity)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.surface2)
                .frame(width: 34, height: 34)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textSoft)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rest timer bar

struct RestTimerBar: View {
    @Environment(AppState.self) private var app
    @State private var remaining: Double = 0

    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            ZStack {
                GeometryReader { geo in
                    let frac = app.restTotal > 0 ? remaining / app.restTotal : 0
                    Rectangle()
                        .fill(LinearGradient(colors: [.purpleDeep, .purplePrimary], startPoint: .leading, endPoint: .trailing))
                        .opacity(0.55)
                        .frame(width: geo.size.width * frac)
                        .animation(.linear(duration: 0.25), value: remaining)
                }
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("REST")
                            .font(.barlow(10, weight: .bold))
                            .kerning(2)
                            .foregroundStyle(Color.glow)
                        Text(Fmt.clock(remaining))
                            .font(.condensed(32, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: Color.glow.opacity(0.6), radius: 7)
                            .monospacedDigit()
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        pillButton("+30s") { app.addRest(30) }
                        pillButton("Skip") { app.stopRest() }
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 62)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.glow.opacity(0.45), lineWidth: 1))
            .shadow(color: Color.purplePrimary.opacity(0.3), radius: 13)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [Color.bg.opacity(0), Color.bg.opacity(0.95)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
        .onAppear { remaining = app.restRemaining }
        .onReceive(timer) { _ in
            remaining = app.restRemaining
            if remaining <= 0 {
                app.stopRest()
                Haptics.success()
            }
        }
    }

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.barlow(12.5, weight: .semibold))
                .foregroundStyle(Color.textMain)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(Capsule().fill(Color.white.opacity(0.1)))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
