import SwiftUI
import SwiftData

/// The live workout. One exercise is in focus at a time — expanded with a big
/// set logger — while the rest collapse to one-line progress rows, so there is
/// never any doubt about what to do next.
struct ActiveWorkoutView: View {
    let workout: Workout

    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var allWorkouts: [Workout]
    @Query private var profiles: [Profile]
    @Query(sort: \BodyMetric.date, order: .reverse) private var metrics: [BodyMetric]

    @State private var focusedID: ObjectIdentifier?
    @State private var editingSetID: ObjectIdentifier?
    @State private var noteEditingID: ObjectIdentifier?
    @State private var showAddPicker = false
    @State private var swapEntry: WorkoutEntry?
    @State private var plateRequest: PlateRequest?
    @State private var historyExercise: ExerciseRef?
    @State private var showSuperset = false
    @State private var showFinishConfirm = false
    @State private var showDiscardConfirm = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var toast: ToastInfo?

    // MARK: Derived state

    private var entries: [WorkoutEntry] { workout.sortedEntries }

    /// The exercise in focus: the one the athlete picked, else the first with
    /// sets left to do.
    private var currentEntry: WorkoutEntry? {
        let list = entries
        if let id = focusedID, let match = list.first(where: { ObjectIdentifier($0) == id }) {
            return match
        }
        return list.first(where: { $0.hasPendingSets }) ?? list.last
    }

    private func isExpanded(_ entry: WorkoutEntry, current: WorkoutEntry?) -> Bool {
        guard let current else { return false }
        if current === entry { return true }
        if let g = current.supersetGroup, entry.supersetGroup == g { return true }
        return false
    }

    private func isDone(_ entry: WorkoutEntry) -> Bool {
        !entry.sets.isEmpty && !entry.hasPendingSets
    }

    private func activeSet(_ entry: WorkoutEntry) -> SetEntry? {
        entry.sortedSets.first { !$0.isCompleted }
    }

    private var allLogged: Bool {
        workout.hasBegun && !entries.isEmpty && !entries.contains { $0.hasPendingSets }
    }

    private var pendingCount: Int {
        workout.entries.flatMap { $0.sets }.filter { !$0.isCompleted }.count
    }

    /// Consecutive exercises in the same superset render as one linked block.
    private var blocks: [ExerciseBlock] {
        var out: [ExerciseBlock] = []
        for e in entries {
            if let g = e.supersetGroup, let last = out.last, last.group == g {
                out[out.count - 1] = ExerciseBlock(id: last.id, entries: last.entries + [e], group: g)
            } else {
                out.append(ExerciseBlock(id: ObjectIdentifier(e), entries: [e], group: e.supersetGroup))
            }
        }
        return out
    }

    // MARK: Body

    var body: some View {
        let current = currentEntry
        return ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 12) {
                        if entries.isEmpty {
                            emptyState
                        } else {
                            ForEach(blocks) { block in
                                blockView(block, current: current)
                            }
                            footerActions
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 200)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onChange(of: focusedID) { _, newID in
                guard let newID else { return }
                withAnimation(.snappy(duration: 0.35)) {
                    proxy.scrollTo(newID, anchor: .top)
                }
            }
            .onAppear {
                if entries.isEmpty {
                    showAddPicker = true
                } else if let cur = currentEntry, cur !== entries.first {
                    DispatchQueue.main.async {
                        proxy.scrollTo(ObjectIdentifier(cur), anchor: .top)
                    }
                }
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .overlay(alignment: .bottom) { bottomDock }
        .overlay(alignment: .top) { toastOverlay }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
                    .font(.barlow(16, weight: .semibold))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddPicker) {
            ExercisePickerView { picked in addExercises(picked) }
        }
        .sheet(item: $swapEntry) { entry in
            ExercisePickerView(singleSelect: true, title: "SWAP EXERCISE") { picked in
                if let ex = picked.first { swap(entry, to: ex) }
            }
        }
        .sheet(item: $plateRequest) { request in
            PlateCalculatorView(initialTargetLb: request.lb)
        }
        .sheet(item: $historyExercise) { ref in
            NavigationStack {
                ExerciseDetailView(exerciseName: ref.name, asSheet: true)
            }
        }
        .sheet(isPresented: $showSuperset) {
            SupersetSheet(workout: workout)
        }
        .confirmationDialog("Finish workout?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
            Button("Finish Workout") { finish() }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text(finishMessage)
        }
        .confirmationDialog("Discard this workout?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Discard Workout", role: .destructive) { discard() }
            Button("Keep It", role: .cancel) {}
        } message: {
            Text("Nothing from this session will be saved.")
        }
        .alert("Rename workout", isPresented: $showRename) {
            TextField("Workout name", text: $renameText)
            Button("Save") { rename() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var finishMessage: String {
        let pending = pendingCount
        if pending > 0 {
            return "\(pending) unlogged set\(pending == 1 ? "" : "s") will be left out."
        }
        return "Every set is logged. Nice work."
    }

    // MARK: Header

    private var header: some View {
        let done = Stats.completedSetCount(workout)
        let total = Stats.totalSetCount(workout)
        let prs = Stats.prSets(workout).count
        return VStack(spacing: 10) {
            ZStack {
                titleBlock
                    .frame(maxWidth: 190)
                HStack(spacing: 6) {
                    IconCircleButton(systemName: "chevron.down") {
                        hideKeyboard()
                        app.workoutPresented = false
                    }
                    .accessibilityLabel("Minimize workout")
                    Spacer()
                    workoutMenu
                    if workout.hasBegun {
                        finishButton
                    }
                }
            }
            .padding(.horizontal, 10)

            if workout.hasBegun && total > 0 {
                VStack(spacing: 8) {
                    HStack(spacing: 7) {
                        Text("\(done) of \(total) sets")
                        Text("·").foregroundStyle(Color.textFaint)
                        Text("\(Fmt.volumeK(Stats.volume(workout))) \(Fmt.unitLabel)")
                        if prs > 0 {
                            Text("·").foregroundStyle(Color.textFaint)
                            Text("\(prs) \(prs == 1 ? "PR" : "PRs")")
                                .foregroundStyle(Color.glow)
                        }
                    }
                    .font(.barlow(13, weight: .semibold))
                    .foregroundStyle(Color.textDim)
                    .contentTransition(.numericText())

                    ThinProgressBar(fraction: Double(done) / Double(total))
                        .padding(.horizontal, 24)
                        .animation(.snappy, value: done)
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(
            Color.sheetBg
                .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1) }
                .ignoresSafeArea(edges: .top)
        )
    }

    private var titleBlock: some View {
        Button {
            renameText = workout.title
            showRename = true
        } label: {
            VStack(spacing: 1) {
                HStack(spacing: 5) {
                    Text(workout.title.uppercased())
                        .font(.barlow(12, weight: .bold))
                        .kerning(1.8)
                        .foregroundStyle(Color.textDim)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.textFaint)
                }
                if workout.hasBegun {
                    Text(workout.startedAt, style: .timer)
                        .font(.condensed(32, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textMain)
                } else {
                    Text("SETUP")
                        .font(.condensed(32, weight: .bold))
                        .kerning(3)
                        .foregroundStyle(Color.textFaint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Rename this workout")
    }

    private var finishButton: some View {
        Button {
            hideKeyboard()
            requestFinish()
        } label: {
            Text("FINISH")
                .font(.condensed(16, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(Capsule().fill(Color.accentGradient))
                .shadow(color: Color.purplePrimary.opacity(0.35), radius: 8)
                .frame(minHeight: Layout.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private var workoutMenu: some View {
        Menu {
            Button {
                renameText = workout.title
                showRename = true
            } label: {
                Label("Rename workout", systemImage: "pencil")
            }
            Button {
                showAddPicker = true
            } label: {
                Label("Add exercises", systemImage: "plus")
            }
            if entries.count >= 2 {
                Button {
                    showSuperset = true
                } label: {
                    Label("Link a superset", systemImage: "link")
                }
            }
            Divider()
            Button(role: .destructive) {
                showDiscardConfirm = true
            } label: {
                Label("Discard workout", systemImage: "trash")
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
    }

    // MARK: Blocks

    @ViewBuilder
    private func blockView(_ block: ExerciseBlock, current: WorkoutEntry?) -> some View {
        if block.entries.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .bold))
                    Text("SUPERSET \(supersetLetter(block.group))")
                        .font(.barlow(12, weight: .bold))
                        .kerning(1.5)
                    Text("· alternate, rest after each round")
                        .font(.barlow(12, weight: .medium))
                        .foregroundStyle(Color.textDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Color.purpleBright)
                .padding(.leading, 6)
                .padding(.top, 2)

                ForEach(block.entries) { entry in
                    entryView(entry, current: current)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.purplePrimary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.purplePrimary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        } else if let entry = block.entries.first {
            entryView(entry, current: current)
        }
    }

    private func supersetLetter(_ group: Int?) -> String {
        guard let group else { return "" }
        let order = blocks.compactMap { $0.entries.count > 1 ? $0.group : nil }
        let letters = Array("ABCDEFGH")
        if let i = order.firstIndex(of: group), i < letters.count { return String(letters[i]) }
        return ""
    }

    @ViewBuilder
    private func entryView(_ entry: WorkoutEntry, current: WorkoutEntry?) -> some View {
        Group {
            if isExpanded(entry, current: current) {
                expandedCard(entry)
            } else if isDone(entry) {
                doneRow(entry)
            } else {
                compactRow(entry)
            }
        }
        .id(ObjectIdentifier(entry))
    }

    // MARK: Collapsed rows

    private func compactRow(_ entry: WorkoutEntry) -> some View {
        let done = entry.completedSets.count
        let total = entry.sets.count
        return Button {
            focus(entry)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    ProgressRing(fraction: total > 0 ? Double(done) / Double(total) : 0, lineWidth: 3.5, size: 40)
                    Text("\(done)/\(total)")
                        .font(.condensed(13, weight: .bold))
                        .foregroundStyle(Color.textSoft)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.condensed(21, weight: .bold))
                        .foregroundStyle(Color.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(compactSubtitle(entry))
                        .font(.barlow(13.5))
                        .foregroundStyle(Color.textDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.textFaint)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
            .card(20)
        }
        .buttonStyle(.pressable)
        .contextMenu { entryMenuItems(entry) }
    }

    private func compactSubtitle(_ entry: WorkoutEntry) -> String {
        guard let next = activeSet(entry) else {
            return "\(entry.sets.count) set\(entry.sets.count == 1 ? "" : "s")"
        }
        return "Next: " + setValueText(next, entry: entry)
    }

    private func doneRow(_ entry: WorkoutEntry) -> some View {
        let hasPR = entry.sets.contains { $0.isPR && $0.isCompleted }
        return Button {
            focus(entry)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Color.successGreen)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.successGreen.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.condensed(20, weight: .bold))
                        .foregroundStyle(Color.textSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(doneSubtitle(entry))
                        .font(.barlow(13.5))
                        .foregroundStyle(Color.textDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if hasPR {
                    PRBadge(filled: true)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
            .card(20)
        }
        .buttonStyle(.pressable)
        .contextMenu { entryMenuItems(entry) }
    }

    private func doneSubtitle(_ entry: WorkoutEntry) -> String {
        let n = entry.completedSets.count
        let setsText = "\(n) set\(n == 1 ? "" : "s")"
        if entry.isDuration {
            let minutes = entry.completedSets.reduce(0) { $0 + $1.reps }
            return "\(setsText) · \(minutes) min"
        }
        let top = entry.workingSets.max { a, b in
            a.weight == b.weight ? a.reps < b.reps : a.weight < b.weight
        }
        if let top, top.weight > 0 {
            return "\(setsText) · top \(Fmt.weight(top.weight)) × \(top.reps)"
        }
        if let top {
            return "\(setsText) · best \(top.reps) reps"
        }
        return setsText
    }

    // MARK: Expanded card

    private func expandedCard(_ entry: WorkoutEntry) -> some View {
        let last = Stats.lastEntry(exerciseName: entry.displayName, workouts: allWorkouts, excluding: workout)
        let prev = last?.workingSets ?? []
        let active = activeSet(entry)
        let editingHere = entry.sets.contains { ObjectIdentifier($0) == editingSetID }
        return VStack(alignment: .leading, spacing: 0) {
            cardHeader(entry, last: last)
            noteSection(entry, lastNote: last?.notes ?? "")
                .padding(.top, 10)
            columnHeader(entry)
                .padding(.top, 14)
            ForEach(entry.sortedSets) { set in
                let showsPanel = ObjectIdentifier(set) == editingSetID || (!editingHere && set === active)
                if showsPanel {
                    SetPanel(
                        set: set,
                        title: set.type == .warmup ? "WARM-UP" : "SET \(setLabel(set, in: entry))",
                        lastText: prevText(set, in: entry, prev: prev),
                        targetText: entry.targetLabel,
                        isDuration: entry.isDuration,
                        showPlates: entry.isBarbell,
                        isLogged: set.isCompleted,
                        onLog: { log(set, in: entry) },
                        onUnlog: { unlog(set) },
                        onClose: {
                            withAnimation(.snappy) { editingSetID = nil }
                        }
                    )
                    .padding(.vertical, 6)
                } else {
                    setRow(set, in: entry, prev: prev)
                }
            }
            addSetButton(entry)
                .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.surface)
                .shadow(color: Brand.isLight ? Color.black.opacity(0.06) : Color.purplePrimary.opacity(0.12), radius: 14, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.purplePrimary.opacity(0.3), lineWidth: 1)
        )
    }

    private func cardHeader(_ entry: WorkoutEntry, last: WorkoutEntry?) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    historyExercise = ExerciseRef(name: entry.displayName)
                } label: {
                    HStack(spacing: 7) {
                        Text(entry.displayName)
                            .font(.condensed(26, weight: .bold))
                            .foregroundStyle(Color.textMain)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.purpleBright)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows this exercise's history")

                Text(metaLine(entry))
                    .font(.barlow(12, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Color.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let last, let date = last.workout?.startedAt {
                    Text("Last · \(Fmt.relative(date)): " + last.workingSets.map { compactSet($0, entry: entry) }.joined(separator: ", "))
                        .font(.barlow(13.5))
                        .foregroundStyle(Color.textSoft)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            Menu {
                entryMenuItems(entry)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textDim)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.surface2))
                    .frame(width: Layout.minTap, height: Layout.minTap)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Exercise options")
        }
    }

    private func metaLine(_ entry: WorkoutEntry) -> String {
        var parts: [String] = []
        if let ex = entry.exercise {
            parts.append(ex.equipment.rawValue.uppercased())
            parts.append(ex.muscle.rawValue.uppercased())
        }
        if let target = entry.targetLabel {
            parts.append(target.uppercased())
        }
        let rest = entry.restSeconds > 0 ? entry.restSeconds : (profiles.first?.defaultRestSeconds ?? 120)
        parts.append("REST \(Fmt.clock(Double(rest)))")
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func noteSection(_ entry: WorkoutEntry, lastNote: String) -> some View {
        let editing = noteEditingID == ObjectIdentifier(entry)
        if editing || !entry.notes.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.purpleBright)
                    .padding(.top, 3)
                TextField(lastNote.isEmpty ? "Seat height, grip, how it felt…" : lastNote, text: noteBinding(entry), axis: .vertical)
                    .font(.barlow(15))
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1...4)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.surface2))
        } else {
            HStack(spacing: 10) {
                Button {
                    noteEditingID = ObjectIdentifier(entry)
                } label: {
                    Label("Add note", systemImage: "note.text")
                        .font(.barlow(14, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if !lastNote.isEmpty {
                    Text("Last: \(lastNote)")
                        .font(.barlow(13.5))
                        .foregroundStyle(Color.textDim)
                        .lineLimit(1)
                }
            }
        }
    }

    private func noteBinding(_ entry: WorkoutEntry) -> Binding<String> {
        Binding(
            get: { entry.notes },
            set: { entry.notes = $0 }
        )
    }

    private func columnHeader(_ entry: WorkoutEntry) -> some View {
        HStack(spacing: 8) {
            Text("SET").frame(width: 34, alignment: .leading)
            Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.isDuration ? "" : Fmt.unitLabel.uppercased()).frame(width: 70)
            Text(entry.isDuration ? "MIN" : "REPS").frame(width: 50)
            Color.clear.frame(width: Layout.minTap, height: 1)
        }
        .font(.barlow(11, weight: .bold))
        .kerning(1.2)
        .foregroundStyle(Color.textFaint)
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    // MARK: Set rows

    private func setRow(_ set: SetEntry, in entry: WorkoutEntry, prev: [SetEntry]) -> some View {
        let pr = set.isCompleted && set.isPR
        return HStack(spacing: 8) {
            setBadge(set, in: entry)
                .frame(width: 34, alignment: .leading)
            HStack(spacing: 6) {
                Text(prevText(set, in: entry, prev: prev) ?? "—")
                    .font(.barlow(14))
                    .foregroundStyle(Color.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if pr {
                    PRBadge(filled: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.isDuration ? "" : (set.weight > 0 ? Fmt.weight(set.weight) : "—"))
                .font(.condensed(22, weight: .bold))
                .foregroundStyle(valueColor(set, pr: pr))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 70)
            Text("\(set.reps)")
                .font(.condensed(22, weight: .bold))
                .foregroundStyle(valueColor(set, pr: pr))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 50)
            checkButton(set, in: entry)
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 52)
        .background(rowBackground(pr: pr))
        .overlay(alignment: .top) {
            if !pr {
                Rectangle().fill(Color.hairlineSoft).frame(height: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
            withAnimation(.snappy) { editingSetID = ObjectIdentifier(set) }
            Haptics.selection()
        }
        .contextMenu { setMenuItems(set, in: entry) }
    }

    @ViewBuilder
    private func rowBackground(pr: Bool) -> some View {
        if pr {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color.purplePrimary.opacity(0.18), Color.glow.opacity(0.04)], startPoint: .leading, endPoint: .trailing))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.glow.opacity(0.5), lineWidth: 1))
        }
    }

    private func valueColor(_ set: SetEntry, pr: Bool) -> Color {
        if pr { return .glow }
        return set.isCompleted ? .textMain : .textFaint
    }

    private func setBadge(_ set: SetEntry, in entry: WorkoutEntry) -> some View {
        let label = setLabel(set, in: entry)
        let pr = set.isCompleted && set.isPR
        let color: Color
        let fill: Color
        switch set.type {
        case .warmup:
            color = .textDim
            fill = .surface2
        case .failure:
            color = .dangerRed
            fill = Color.dangerRed.opacity(0.12)
        case .drop:
            color = .purpleBright
            fill = Color.purplePrimary.opacity(0.14)
        case .working:
            color = pr ? .glow : .textSoft
            fill = pr ? Color.glow.opacity(0.18) : .surface2
        }
        return Text(label)
            .font(.condensed(16, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(fill))
    }

    private func checkButton(_ set: SetEntry, in entry: WorkoutEntry) -> some View {
        Button {
            if set.isCompleted {
                unlog(set)
            } else {
                log(set, in: entry)
            }
        } label: {
            ZStack {
                if set.isCompleted {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.successGreen.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.successGreen.opacity(0.45), lineWidth: 1)
                        )
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Color.successGreen)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.outline, lineWidth: 1.5)
                }
            }
            .frame(width: 34, height: 34)
            .frame(width: Layout.minTap, height: Layout.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(set.isCompleted ? "Logged. Double-tap to undo." : "Log this set")
    }

    private func addSetButton(_ entry: WorkoutEntry) -> some View {
        Button {
            addSet(to: entry)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Add set")
                    .font(.barlow(15, weight: .semibold))
            }
            .foregroundStyle(Color.purpleBright)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.minTap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
    }

    // MARK: Menus

    @ViewBuilder
    private func setMenuItems(_ set: SetEntry, in entry: WorkoutEntry) -> some View {
        Button {
            withAnimation(.snappy) { editingSetID = ObjectIdentifier(set) }
        } label: {
            Label("Edit set", systemImage: "pencil")
        }
        if set.isCompleted {
            Button {
                unlog(set)
            } label: {
                Label("Mark as not done", systemImage: "arrow.uturn.backward")
            }
        }
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button {
                    set.type = type
                    save()
                } label: {
                    Label(type.menuTitle, systemImage: type.icon)
                }
            }
        } label: {
            Label("Set type", systemImage: "tag")
        }
        Button(role: .destructive) {
            deleteSet(set, from: entry)
        } label: {
            Label("Delete set", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func entryMenuItems(_ entry: WorkoutEntry) -> some View {
        Button {
            historyExercise = ExerciseRef(name: entry.displayName)
        } label: {
            Label("Exercise history", systemImage: "chart.line.uptrend.xyaxis")
        }
        if canAddWarmups(entry) {
            Button {
                addWarmups(to: entry)
            } label: {
                Label("Add warm-up sets", systemImage: "thermometer.low")
            }
        }
        if entry.isBarbell {
            Button {
                plateRequest = PlateRequest(lb: plateWeight(entry))
            } label: {
                Label("Plate calculator", systemImage: "scalemass")
            }
        }
        if entry.completedSets.isEmpty {
            Button {
                swapEntry = entry
            } label: {
                Label("Swap exercise", systemImage: "arrow.left.arrow.right")
            }
        }
        Button {
            noteEditingID = ObjectIdentifier(entry)
            focus(entry)
        } label: {
            Label(entry.notes.isEmpty ? "Add note" : "Edit note", systemImage: "note.text")
        }
        if entry.supersetGroup != nil {
            Button {
                entry.supersetGroup = nil
                save()
            } label: {
                Label("Remove from superset", systemImage: "link")
            }
        }
        if entries.first !== entry {
            Button {
                move(entry, by: -1)
            } label: {
                Label("Move up", systemImage: "arrow.up")
            }
        }
        if entries.last !== entry {
            Button {
                move(entry, by: 1)
            } label: {
                Label("Move down", systemImage: "arrow.down")
            }
        }
        Divider()
        Button(role: .destructive) {
            remove(entry)
        } label: {
            Label("Remove exercise", systemImage: "trash")
        }
    }

    // MARK: Empty state & footer

    private var emptyState: some View {
        VStack(spacing: 14) {
            Hexagon()
                .fill(LinearGradient(colors: [.surface2, .surface], startPoint: .top, endPoint: .bottom))
                .frame(width: 88, height: 96)
                .overlay(Hexagon().stroke(Color.purplePrimary.opacity(0.4), lineWidth: 1.5))
                .overlay(LogoBars(barWidth: 6, barHeight: 22, glowRadius: 7))
            Text(Brand.setupTitle)
                .font(.condensed(26, weight: .heavy))
                .kerning(1.5)
                .foregroundStyle(Color.textMain)
                .multilineTextAlignment(.center)
            Text("Add your exercises, then press Start. The clock waits for you.")
                .font(.barlow(15))
                .foregroundStyle(Color.textDim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            GradientCTA("ADD EXERCISES", systemIcon: "plus") {
                showAddPicker = true
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 12)
        .padding(.top, 44)
    }

    private var footerActions: some View {
        VStack(spacing: 10) {
            DashedButton("Add exercise") {
                showAddPicker = true
            }
            if entries.count >= 2 {
                Button {
                    showSuperset = true
                } label: {
                    Label("Link a superset", systemImage: "link")
                        .font(.barlow(14.5, weight: .semibold))
                        .foregroundStyle(Color.textSoft)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.top, 4)
    }

    // MARK: Bottom dock

    @ViewBuilder
    private var bottomDock: some View {
        if !workout.hasBegun {
            if !entries.isEmpty {
                GradientCTA("START WORKOUT", systemIcon: "play.fill") {
                    begin()
                }
                .padding(.horizontal, 16)
                .padding(.top, 28)
                .padding(.bottom, 10)
                .background(dockFade)
            }
        } else if app.restEndsAt != nil {
            RestDock()
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if allLogged {
            VStack(spacing: 8) {
                Text("Every set is logged.")
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(Color.textDim)
                GradientCTA("FINISH WORKOUT", systemIcon: "flag.checkered") {
                    requestFinish()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 28)
            .padding(.bottom, 10)
            .background(dockFade)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var dockFade: some View {
        LinearGradient(colors: [Color.bg.opacity(0), Color.bg.opacity(0.94), Color.bg], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast {
            RecordToast(title: Brand.prToastTitle, message: toast.message)
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    withAnimation(.snappy) { self.toast = nil }
                }
        }
    }

    // MARK: Text helpers

    private func setLabel(_ set: SetEntry, in entry: WorkoutEntry) -> String {
        if set.type == .warmup { return "W" }
        var n = 0
        for s in entry.sortedSets {
            if s.type != .warmup { n += 1 }
            if s === set { break }
        }
        return "\(n)"
    }

    /// What the athlete did at this position last session.
    private func prevText(_ set: SetEntry, in entry: WorkoutEntry, prev: [SetEntry]) -> String? {
        guard set.type != .warmup else { return nil }
        let working = entry.sortedSets.filter { $0.type != .warmup }
        let idx = working.firstIndex { $0 === set } ?? 0
        guard let p = prev[safe: idx] ?? prev.last else { return nil }
        return compactSet(p, entry: entry)
    }

    private func compactSet(_ s: SetEntry, entry: WorkoutEntry) -> String {
        if entry.isDuration { return "\(s.reps) min" }
        if s.weight > 0 { return "\(Fmt.weight(s.weight)) × \(s.reps)" }
        return "\(s.reps) reps"
    }

    private func setValueText(_ set: SetEntry, entry: WorkoutEntry) -> String {
        if entry.isDuration { return "\(set.reps) min" }
        if set.weight > 0 { return "\(Fmt.weight(set.weight)) \(Fmt.unitLabel) × \(set.reps)" }
        return "\(set.reps) reps"
    }

    // MARK: Actions — focus & logging

    private func focus(_ entry: WorkoutEntry) {
        hideKeyboard()
        withAnimation(.snappy(duration: 0.35)) {
            editingSetID = nil
            focusedID = ObjectIdentifier(entry)
        }
        Haptics.selection()
    }

    private func begin() {
        guard !workout.hasBegun else { return }
        workout.startedAt = Date()
        workout.hasBegun = true
        save()
        Haptics.success()
    }

    private func log(_ set: SetEntry, in entry: WorkoutEntry) {
        if !workout.hasBegun { begin() }

        // "Save changes" on a set that was already logged just closes the editor.
        if set.isCompleted {
            withAnimation(.snappy) { editingSetID = nil }
            Stats.recomputePRs(in: workout, all: allWorkouts)
            save()
            Haptics.tap()
            return
        }

        set.isCompleted = true
        set.completedAt = Date()
        set.bodyLoad = bodyLoad(for: entry)
        carryForward(from: set, in: entry)

        Stats.recomputePRs(in: workout, all: allWorkouts)
        if set.isPR {
            Haptics.pr()
            showRecordToast(entry: entry, set: set)
        } else {
            Haptics.medium()
        }

        let next = nextUp(after: entry)
        if next != nil && !skipsRest(after: entry) {
            let seconds = entry.restSeconds > 0 ? entry.restSeconds : (profiles.first?.defaultRestSeconds ?? 120)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                app.startRest(seconds: seconds, next: next.map { restNext(for: $0.set, in: $0.entry) })
            }
            RestAlerts.requestIfNeeded()
        }

        withAnimation(.snappy(duration: 0.35)) {
            editingSetID = nil
            if let next, next.entry !== entry {
                focusedID = ObjectIdentifier(next.entry)
            }
        }
        save()
    }

    private func unlog(_ set: SetEntry) {
        set.isCompleted = false
        set.isPR = false
        set.completedAt = nil
        set.bodyLoad = 0
        withAnimation(.snappy) { editingSetID = nil }
        Stats.recomputePRs(in: workout, all: allWorkouts)
        Haptics.tap()
        save()
    }

    /// The set that should come after one in `entry` was logged.
    private func nextUp(after entry: WorkoutEntry) -> (entry: WorkoutEntry, set: SetEntry)? {
        let list = entries
        if let g = entry.supersetGroup {
            let group = list.filter { $0.supersetGroup == g }
            if group.count > 1, let i = group.firstIndex(where: { $0 === entry }) {
                // Partners after this one first, wrapping around the group.
                let rotated = Array(group[(i + 1)...]) + Array(group[..<i])
                let myDone = entry.completedSets.count
                if let partner = rotated.first(where: { $0.completedSets.count < myDone && $0.hasPendingSets }),
                   let s = activeSet(partner) {
                    return (partner, s)
                }
                // Round complete: start the next one from the top of the group.
                if let first = group.first(where: { $0.hasPendingSets }), let s = activeSet(first) {
                    return (first, s)
                }
            }
        }
        if let s = activeSet(entry) { return (entry, s) }
        if let i = list.firstIndex(where: { $0 === entry }) {
            let rest = Array(list[(i + 1)...]) + Array(list[..<i])
            if let e = rest.first(where: { $0.hasPendingSets }), let s = activeSet(e) {
                return (e, s)
            }
        }
        return nil
    }

    /// Supersets rest after the round, not between partners.
    private func skipsRest(after entry: WorkoutEntry) -> Bool {
        guard let g = entry.supersetGroup else { return false }
        let myDone = entry.completedSets.count
        return entries.contains {
            $0.supersetGroup == g && $0 !== entry && $0.completedSets.count < myDone && $0.hasPendingSets
        }
    }

    private func restNext(for set: SetEntry, in entry: WorkoutEntry) -> RestNext {
        let label = set.type == .warmup ? "Warm-up" : "Set \(setLabel(set, in: entry))"
        return RestNext(title: "\(label) · \(entry.displayName)", detail: setValueText(set, entry: entry))
    }

    /// A weight typed on one set flows into the untouched sets after it.
    private func carryForward(from set: SetEntry, in entry: WorkoutEntry) {
        guard set.weight > 0, set.type != .warmup else { return }
        for later in entry.sortedSets where later.orderIndex > set.orderIndex && !later.isCompleted && later.type != .warmup {
            if later.weight == 0 { later.weight = set.weight }
            if later.reps == 0 { later.reps = set.reps }
        }
    }

    /// Bodyweight moves count the athlete's logged bodyweight toward volume.
    private func bodyLoad(for entry: WorkoutEntry) -> Double {
        guard let ex = entry.exercise, ex.equipment == .bodyweight, !ex.muscle.isDuration else { return 0 }
        return metrics.compactMap { $0.weight }.first ?? 0
    }

    private func showRecordToast(entry: WorkoutEntry, set: SetEntry) {
        let detail = set.weight > 0
            ? "\(entry.displayName) · \(Fmt.weight(set.weight)) × \(set.reps)"
            : "\(entry.displayName) · \(set.reps) reps"
        let info = ToastInfo(message: detail)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            toast = info
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            if toast?.id == info.id {
                withAnimation(.easeOut(duration: 0.3)) { toast = nil }
            }
        }
    }

    // MARK: Actions — editing the workout

    private func addSet(to entry: WorkoutEntry) {
        let template = entry.sortedSets.last(where: { $0.type != .warmup }) ?? entry.sortedSets.last
        let set = SetEntry(
            orderIndex: (entry.sets.map { $0.orderIndex }.max() ?? -1) + 1,
            weight: template?.weight ?? 0,
            reps: template?.reps ?? (entry.isDuration ? 10 : 8),
            type: .working
        )
        context.insert(set)
        entry.sets.append(set)
        save()
        Haptics.tap()
    }

    private func deleteSet(_ set: SetEntry, from entry: WorkoutEntry) {
        if editingSetID == ObjectIdentifier(set) { editingSetID = nil }
        withAnimation(.snappy) {
            entry.sets.removeAll { $0 === set }
            context.delete(set)
        }
        Stats.recomputePRs(in: workout, all: allWorkouts)
        save()
    }

    private func addExercises(_ picked: [Exercise]) {
        let current = currentEntry
        let before = Set(workout.entries.map { ObjectIdentifier($0) })
        for ex in picked {
            WorkoutBuilder.addExercise(
                ex, to: workout, context: context,
                history: allWorkouts,
                defaultRest: profiles.first?.defaultRestSeconds ?? 120
            )
        }
        // Jump to what was just added unless the athlete is mid-exercise.
        let midExercise = current.map { $0.hasPendingSets && !$0.completedSets.isEmpty } ?? false
        if !midExercise, let first = entries.first(where: { !before.contains(ObjectIdentifier($0)) }) {
            withAnimation(.snappy) { focusedID = ObjectIdentifier(first) }
        }
    }

    private func swap(_ entry: WorkoutEntry, to exercise: Exercise) {
        entry.exercise = exercise
        entry.exerciseName = exercise.name
        let prev = Stats.lastSets(exerciseName: exercise.name, workouts: allWorkouts, excluding: workout)
        let working = entry.sortedSets.filter { $0.type != .warmup }
        for (i, s) in working.enumerated() where !s.isCompleted {
            let p = i < prev.count ? prev[i] : prev.last
            s.weight = p?.weight ?? 0
            if let p { s.reps = p.reps }
        }
        // Warm-ups were built for the old lift.
        let staleWarmups = entry.sets.filter { $0.type == .warmup && !$0.isCompleted }
        for s in staleWarmups {
            entry.sets.removeAll { $0 === s }
            context.delete(s)
        }
        save()
        Haptics.success()
    }

    private func canAddWarmups(_ entry: WorkoutEntry) -> Bool {
        guard !entry.isDuration, entry.exercise?.equipment != .bodyweight else { return false }
        guard entry.completedSets.isEmpty, !entry.sets.contains(where: { $0.type == .warmup }) else { return false }
        return entry.sets.contains { $0.type != .warmup && $0.weight > 0 }
    }

    private func addWarmups(to entry: WorkoutEntry) {
        guard let working = entry.sortedSets.first(where: { $0.type != .warmup && $0.weight > 0 }) else { return }
        let ramp = Stats.warmupRamp(workingLb: working.weight, barbell: entry.isBarbell)
        guard !ramp.isEmpty else { return }
        for s in entry.sets { s.orderIndex += ramp.count }
        withAnimation(.snappy) {
            for (i, step) in ramp.enumerated() {
                let s = SetEntry(orderIndex: i, weight: step.lb, reps: step.reps, type: .warmup)
                context.insert(s)
                entry.sets.append(s)
            }
        }
        focus(entry)
        save()
        Haptics.success()
    }

    private func plateWeight(_ entry: WorkoutEntry) -> Double {
        if let w = activeSet(entry)?.weight, w > 0 { return w }
        if let w = entry.sortedSets.last?.weight, w > 0 { return w }
        return Fmt.unit.toLb(Fmt.unit == .lb ? 135 : 60)
    }

    private func move(_ entry: WorkoutEntry, by delta: Int) {
        var list = entries
        guard let i = list.firstIndex(where: { $0 === entry }) else { return }
        let j = i + delta
        guard list.indices.contains(j) else { return }
        list.swapAt(i, j)
        withAnimation(.snappy) {
            for (k, e) in list.enumerated() { e.orderIndex = k }
        }
        save()
    }

    private func remove(_ entry: WorkoutEntry) {
        if focusedID == ObjectIdentifier(entry) { focusedID = nil }
        if let id = editingSetID, entry.sets.contains(where: { ObjectIdentifier($0) == id }) {
            editingSetID = nil
        }
        withAnimation(.snappy) {
            workout.entries.removeAll { $0 === entry }
            context.delete(entry)
        }
        Stats.recomputePRs(in: workout, all: allWorkouts)
        save()
    }

    private func rename() {
        let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        workout.title = t
        save()
    }

    // MARK: Actions — finishing

    private func requestFinish() {
        if Stats.completedSetCount(workout) == 0 {
            showDiscardConfirm = true
        } else {
            showFinishConfirm = true
        }
    }

    private func finish() {
        WorkoutBuilder.cleanUp(workout, context: context)
        if workout.title == WorkoutBuilder.defaultTitle {
            workout.title = Stats.autoTitle(workout)
        }
        workout.endedAt = Date()
        Stats.recomputePRs(in: workout, all: allWorkouts)

        let gained = RankSystem.xp(for: workout)
        let before = RankSystem.totalXP(allWorkouts.filter { $0 !== workout })
        app.summary = WorkoutSummary(xpGained: gained, xpBefore: before, xpAfter: before + gained)

        save()
        app.stopRest()
        Haptics.success()
        withAnimation(.easeInOut(duration: 0.3)) {
            app.showSummary = true
        }
    }

    private func discard() {
        let doomed = workout
        let ctx = context
        app.endWorkoutFlow()
        // Delete after the screen is gone so nothing renders a deleted object.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ctx.delete(doomed)
            try? ctx.save()
        }
    }

    private func save() {
        try? context.save()
    }
}

// MARK: - Supporting types

private struct ExerciseBlock: Identifiable {
    let id: ObjectIdentifier
    let entries: [WorkoutEntry]
    let group: Int?
}

private struct ToastInfo: Equatable {
    let id = UUID()
    let message: String
}

struct ExerciseRef: Identifiable, Hashable {
    let name: String
    var id: String { name }
}

struct PlateRequest: Identifiable {
    let id = UUID()
    let lb: Double
}

extension SetType {
    var title: String {
        switch self {
        case .working: return "WORKING"
        case .warmup: return "WARM-UP"
        case .failure: return "TO FAILURE"
        case .drop: return "DROP SET"
        }
    }

    var menuTitle: String {
        switch self {
        case .working: return "Working set — a normal set"
        case .warmup: return "Warm-up — light prep, no PR check"
        case .failure: return "To failure — went to max effort"
        case .drop: return "Drop set — stripped weight, kept going"
        }
    }

    var icon: String {
        switch self {
        case .working: return "dumbbell"
        case .warmup: return "thermometer.low"
        case .failure: return "flame"
        case .drop: return "arrow.down.right"
        }
    }

    var tint: Color {
        switch self {
        case .working: return .purplePrimary
        case .warmup: return .textDim
        case .failure: return .dangerRed
        case .drop: return .purpleMid
        }
    }
}

// MARK: - Set logger panel

/// The big, thumb-sized logger for one set.
struct SetPanel: View {
    let set: SetEntry
    let title: String
    let lastText: String?
    let targetText: String?
    let isDuration: Bool
    let showPlates: Bool
    let isLogged: Bool
    let onLog: () -> Void
    let onUnlog: () -> Void
    let onClose: () -> Void

    private var weight: Binding<Double> {
        Binding(
            get: { (Prefs.shared.unit.fromLb(set.weight) * 100).rounded() / 100 },
            set: { set.weight = max(0, Prefs.shared.unit.toLb($0)) }
        )
    }

    private var reps: Binding<Double> {
        Binding(
            get: { Double(set.reps) },
            set: { set.reps = max(0, min(999, Int($0.rounded()))) }
        )
    }

    var body: some View {
        let unit = Fmt.unit
        return VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.condensed(19, weight: .heavy))
                    .kerning(1.2)
                    .foregroundStyle(Color.purpleBright)
                typeMenu
                Spacer(minLength: 4)
                if let lastText {
                    Text("LAST \(lastText)")
                        .font(.barlow(12.5, weight: .semibold))
                        .foregroundStyle(Color.textDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if isLogged {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.textDim)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.surface))
                            .frame(width: Layout.minTap, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close editor")
                }
            }

            HStack(spacing: 10) {
                if !isDuration {
                    StepperField(label: unit.label.uppercased(), value: weight, step: unit.step, decimals: true)
                }
                StepperField(label: isDuration ? "MIN" : "REPS", value: reps, step: 1, decimals: false)
            }

            if let hint = hintText {
                Text(hint)
                    .font(.barlow(13, weight: .medium))
                    .foregroundStyle(Color.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                if isLogged {
                    Button {
                        hideKeyboard()
                        onUnlog()
                    } label: {
                        Text("Undo log")
                            .font(.barlow(15, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                            .frame(width: 104, height: 54)
                            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.surface))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.strokeStrong, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                }
                Button {
                    hideKeyboard()
                    onLog()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                        Text(isLogged ? "SAVE CHANGES" : "LOG SET")
                            .font(.condensed(19, weight: .bold))
                            .kerning(2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.accentGradient))
                    .shadow(color: Color.purplePrimary.opacity(0.4), radius: 10, y: 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.surface2))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.purplePrimary.opacity(0.45), lineWidth: 1.5))
    }

    private var hintText: String? {
        var parts: [String] = []
        if let targetText { parts.append("Target \(targetText)") }
        if showPlates && !isDuration, let plates = PlateMath.summary(lb: set.weight) {
            parts.append(plates)
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    private var typeMenu: some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button {
                    set.type = type
                    Haptics.selection()
                } label: {
                    Label(type.menuTitle, systemImage: type.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(set.type.title)
                    .font(.barlow(12, weight: .bold))
                    .kerning(0.8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(set.type == .working ? Color.textDim : Color.white)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Capsule().fill(set.type == .working ? Color.clear : set.type.tint))
            .overlay(Capsule().stroke(set.type == .working ? Color.outline : Color.clear, lineWidth: 1))
            .contentShape(Capsule())
        }
        .accessibilityLabel("Set type: \(set.type.title)")
    }
}

// MARK: - Rest dock

/// Countdown, what's next, and quick adjustments — pinned above the thumb.
struct RestDock: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let end = app.restEndsAt {
            TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                let remaining = max(0, end.timeIntervalSince(timeline.date))
                let fraction = app.restTotal > 0 ? remaining / app.restTotal : 0
                dock(remaining: remaining, fraction: fraction)
            }
            .padding(.horizontal, 14)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .background(
                LinearGradient(colors: [Color.bg.opacity(0), Color.bg.opacity(0.9), Color.bg], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private func dock(remaining: Double, fraction: Double) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    ProgressRing(fraction: fraction, lineWidth: 5, size: 56)
                    Image(systemName: "timer")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.purpleBright)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("REST")
                        .font(.barlow(11.5, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(Color.purpleBright)
                    Text(Fmt.clock(remaining.rounded(.up)))
                        .font(.condensed(40, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.textMain)
                }
                Spacer(minLength: 6)
                if let next = app.restNext {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("UP NEXT")
                            .font(.barlow(11, weight: .bold))
                            .kerning(1.6)
                            .foregroundStyle(Color.textFaint)
                        Text(next.title)
                            .font(.barlow(14, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(next.detail)
                            .font(.condensed(19, weight: .bold))
                            .foregroundStyle(Color.textSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            HStack(spacing: 8) {
                adjustButton("−15s") { app.addRest(-15) }
                adjustButton("+15s") { app.addRest(15) }
                Spacer()
                Button {
                    withAnimation(.snappy) { app.stopRest() }
                    Haptics.tap()
                } label: {
                    Text("SKIP")
                        .font(.condensed(16, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .frame(height: 40)
                        .background(Capsule().fill(Color.accentGradient))
                        .frame(minHeight: Layout.minTap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Skip rest")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.surfaceRaised)
                .shadow(color: Brand.isLight ? Color.black.opacity(0.1) : Color.purplePrimary.opacity(0.25), radius: 16, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.purplePrimary.opacity(0.4), lineWidth: 1)
        )
    }

    private func adjustButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            Text(title)
                .font(.barlow(14, weight: .semibold))
                .foregroundStyle(Color.textMain)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Capsule().fill(Color.surface2))
                .overlay(Capsule().stroke(Color.strokeStrong, lineWidth: 1))
                .frame(minHeight: Layout.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Superset sheet

struct SupersetSheet: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<ObjectIdentifier> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(16, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 70, alignment: .leading)
                Spacer()
                Text("SUPERSET")
                    .font(.condensed(20, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Color.clear.frame(width: 70, height: 1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)

            Text("Pick two or more exercises. You'll do a set of one, go straight to the next, and rest only after the round.")
                .font(.barlow(15))
                .lineSpacing(3)
                .foregroundStyle(Color.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(workout.sortedEntries) { entry in
                        entryRow(entry)
                        Divider().overlay(Color.hairlineSoft).padding(.leading, 18)
                    }
                }
                .padding(.bottom, 100)
            }
            .overlay(alignment: .bottom) {
                GradientCTA(selected.count >= 2 ? "LINK \(selected.count) EXERCISES" : "PICK AT LEAST 2", fontSize: 18) {
                    link()
                }
                .opacity(selected.count >= 2 ? 1 : 0.45)
                .disabled(selected.count < 2)
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .padding(.top, 20)
                .background(
                    LinearGradient(colors: [Color.sheetBg.opacity(0), Color.sheetBg], startPoint: .top, endPoint: .bottom)
                )
            }
        }
        .background(Color.sheetBg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func entryRow(_ entry: WorkoutEntry) -> some View {
        let isSelected = selected.contains(ObjectIdentifier(entry))
        return Button {
            if isSelected {
                selected.remove(ObjectIdentifier(entry))
            } else {
                selected.insert(ObjectIdentifier(entry))
            }
            Haptics.selection()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.barlow(16.5, weight: .semibold))
                        .foregroundStyle(Color.textMain)
                    if entry.supersetGroup != nil {
                        Text("Already linked — picking it moves it to the new superset")
                            .font(.barlow(12.5))
                            .foregroundStyle(Color.purpleBright.opacity(0.85))
                    }
                }
                Spacer()
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.accentGradient)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .stroke(Color.outline, lineWidth: 1.5)
                    }
                }
                .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .background(isSelected ? Color.purplePrimary.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func link() {
        let group = (workout.entries.compactMap { $0.supersetGroup }.max() ?? 0) + 1
        let ordered = workout.sortedEntries
        let chosen = ordered.filter { selected.contains(ObjectIdentifier($0)) }
        guard let anchor = chosen.first else { return }
        for e in chosen { e.supersetGroup = group }
        // Keep linked exercises together, where the first one already sits.
        var reordered = ordered.filter { !selected.contains(ObjectIdentifier($0)) }
        let insertAt = reordered.firstIndex(where: { $0.orderIndex > anchor.orderIndex }) ?? reordered.count
        reordered.insert(contentsOf: chosen, at: insertAt)
        for (i, e) in reordered.enumerated() { e.orderIndex = i }
        Haptics.success()
        dismiss()
    }
}
