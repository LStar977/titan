import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var editing: Routine?
    @State private var editingIsNew = false

    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BackHeader(label: "Home", trailing: AnyView(newButton)) { dismiss() }

                Text("ROUTINES")
                    .font(.condensed(36, weight: .heavy))
                    .kerning(2)
                    .foregroundStyle(Color.textMain)

                SectionLabel("My templates · \(routines.count)")
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                VStack(spacing: 10) {
                    ForEach(routines) { routine in
                        routineCard(routine)
                    }

                    Button {
                        createRoutine()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("New Routine")
                                .font(.barlow(13, weight: .semibold))
                        }
                        .foregroundStyle(Color.purpleBright)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.purplePrimary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $editing) { routine in
            RoutineEditorView(routine: routine, isNew: editingIsNew)
        }
    }

    private var newButton: some View {
        Button {
            createRoutine()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.surface2))
        }
        .buttonStyle(.plain)
    }

    private func createRoutine() {
        let r = Routine(name: "New Routine", orderIndex: (routines.map { $0.orderIndex }.max() ?? -1) + 1)
        context.insert(r)
        editingIsNew = true
        editing = r
    }

    private var upNext: Routine? {
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

    private func routineCard(_ routine: Routine) -> some View {
        let isNext = upNext === routine
        return Button {
            editingIsNew = false
            editing = routine
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(routine.name)
                            .font(.condensed(22, weight: .bold))
                            .foregroundStyle(Color.textMain)
                        Text(subtitle(routine))
                            .font(.barlow(11.5))
                            .foregroundStyle(Color.textDim)
                    }
                    Spacer()
                    if isNext {
                        Text("NEXT UP")
                            .font(.barlow(9.5, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(Color.purpleBright)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.purplePrimary.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1))
                    } else {
                        menuButton(routine)
                    }
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
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(16, border: isNext ? Color.purplePrimary.opacity(0.3) : .hairline)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                startRoutine(routine)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
            Button {
                editingIsNew = false
                editing = routine
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                duplicate(routine)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) {
                context.delete(routine)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func menuButton(_ routine: Routine) -> some View {
        Menu {
            Button {
                startRoutine(routine)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
            }
            Button {
                editingIsNew = false
                editing = routine
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                duplicate(routine)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Button(role: .destructive) {
                context.delete(routine)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.textFaint)
                .frame(width: 30, height: 24, alignment: .trailing)
                .contentShape(Rectangle())
        }
    }

    private func subtitle(_ routine: Routine) -> String {
        var parts = ["\(routine.items.count) exercises"]
        if let last = lastDone(routine) {
            if Calendar.current.isDateInToday(last) {
                parts.append("done today")
            } else {
                parts.append("last \(Fmt.shortDate(last))")
            }
        }
        return parts.joined(separator: " · ")
    }

    private func startRoutine(_ routine: Routine) {
        let w = WorkoutBuilder.start(routine: routine, context: context, history: workouts)
        app.activeWorkout = w
        app.showSummary = false
        app.workoutPresented = true
        Haptics.medium()
    }

    private func duplicate(_ routine: Routine) {
        let copy = Routine(name: routine.name + " Copy", orderIndex: (routines.map { $0.orderIndex }.max() ?? -1) + 1)
        context.insert(copy)
        for item in routine.sortedItems {
            let ri = RoutineItem(
                orderIndex: item.orderIndex,
                exercise: item.exercise,
                plannedSets: item.plannedSets,
                repLow: item.repLow,
                repHigh: item.repHigh,
                restSeconds: item.restSeconds,
                supersetGroup: item.supersetGroup
            )
            context.insert(ri)
            copy.items.append(ri)
        }
        try? context.save()
    }
}

// MARK: - Routine editor

struct RoutineEditorView: View {
    let routine: Routine
    var isNew = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var showPicker = false
    @State private var editingItem: RoutineItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    if isNew { context.delete(routine) }
                    dismiss()
                }
                .font(.barlow(14, weight: .medium))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 64, alignment: .leading)
                Spacer()
                Text(isNew ? "NEW ROUTINE" : "EDIT ROUTINE")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Save") {
                    routine.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : name.trimmingCharacters(in: .whitespaces)
                    try? context.save()
                    dismiss()
                }
                .font(.barlow(14, weight: .bold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 64, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }

            List {
                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ROUTINE NAME")
                            .font(.barlow(9.5, weight: .bold))
                            .kerning(1.5)
                            .foregroundStyle(Color.textFaint)
                        TextField("Routine name", text: $name)
                            .font(.condensed(22, weight: .bold))
                            .foregroundStyle(Color.textMain)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.surface2)
                }

                Section {
                    ForEach(routine.sortedItems) { item in
                        itemRow(item)
                            .listRowBackground(Color.surface)
                    }
                    .onMove(perform: moveItems)
                } header: {
                    Text("EXERCISES · \(routine.items.count) · HOLD & DRAG TO REORDER")
                        .font(.barlow(11, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.textDim)
                }

                Section {
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
                    }
                    .listRowBackground(Color.surface)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { name = routine.name }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { picked in
                var next = (routine.items.map { $0.orderIndex }.max() ?? -1) + 1
                for ex in picked {
                    let item = RoutineItem(orderIndex: next, exercise: ex)
                    context.insert(item)
                    routine.items.append(item)
                    next += 1
                }
            }
        }
        .sheet(item: $editingItem) { item in
            RoutineItemSheet(item: item)
        }
    }

    private func itemRow(_ item: RoutineItem) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 7) {
                        Text(item.displayName)
                            .font(.barlow(14.5, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                        if let g = item.supersetGroup {
                            Text("SS \(supersetLetter(g))")
                                .font(.barlow(8.5, weight: .bold))
                                .kerning(1)
                                .foregroundStyle(Color.purpleBright)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.purplePrimary.opacity(0.45), lineWidth: 1))
                        }
                    }
                    Text("\(item.plannedSets) sets · \(item.repLow)–\(item.repHigh) reps · rest \(Fmt.clock(Double(item.restSeconds)))")
                        .font(.barlow(11.5))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textFaint)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                groupWithNext(item)
            } label: {
                Label("Group with next (superset)", systemImage: "arrow.triangle.swap")
            }
            if item.supersetGroup != nil {
                Button {
                    item.supersetGroup = nil
                } label: {
                    Label("Ungroup superset", systemImage: "xmark.circle")
                }
            }
            Button(role: .destructive) {
                routine.items.removeAll { $0 === item }
                context.delete(item)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func supersetLetter(_ group: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        let groups = Array(Set(routine.items.compactMap { $0.supersetGroup })).sorted()
        if let idx = groups.firstIndex(of: group), idx < letters.count { return letters[idx] }
        return "A"
    }

    private func groupWithNext(_ item: RoutineItem) {
        let items = routine.sortedItems
        guard let idx = items.firstIndex(where: { $0 === item }), idx + 1 < items.count else { return }
        let next = items[idx + 1]
        if let g = item.supersetGroup {
            next.supersetGroup = g
        } else if let g = next.supersetGroup {
            item.supersetGroup = g
        } else {
            let g = (routine.items.compactMap { $0.supersetGroup }.max() ?? 0) + 1
            item.supersetGroup = g
            next.supersetGroup = g
        }
        Haptics.tap()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = routine.sortedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (i, item) in items.enumerated() {
            item.orderIndex = i
        }
    }
}

// MARK: - Per-exercise prescription sheet

struct RoutineItemSheet: View {
    let item: RoutineItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text(item.displayName.uppercased())
                .font(.condensed(24, weight: .bold))
                .kerning(1)
                .foregroundStyle(Color.textMain)
                .padding(.top, 22)

            stepperRow("Sets", value: "\(item.plannedSets)") {
                item.plannedSets = max(1, item.plannedSets - 1)
            } plus: {
                item.plannedSets = min(10, item.plannedSets + 1)
            }

            stepperRow("Rep range low", value: "\(item.repLow)") {
                item.repLow = max(1, item.repLow - 1)
            } plus: {
                item.repLow = min(item.repHigh, item.repLow + 1)
            }

            stepperRow("Rep range high", value: "\(item.repHigh)") {
                item.repHigh = max(item.repLow, item.repHigh - 1)
            } plus: {
                item.repHigh = min(50, item.repHigh + 1)
            }

            stepperRow("Rest", value: Fmt.clock(Double(item.restSeconds))) {
                item.restSeconds = max(0, item.restSeconds - 15)
            } plus: {
                item.restSeconds = min(600, item.restSeconds + 15)
            }

            GradientCTA("DONE", height: 48, fontSize: 17) { dismiss() }
                .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color(hex: 0x10101B).ignoresSafeArea())
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
    }

    private func stepperRow(_ label: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.barlow(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(Color.textDim)
            Spacer()
            HStack(spacing: 14) {
                smallStep("minus", action: minus)
                Text(value)
                    .font(.condensed(24, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .frame(minWidth: 58)
                    .monospacedDigit()
                smallStep("plus", action: plus)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .card(13)
    }

    private func smallStep(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.surface2)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textSoft)
                )
        }
        .buttonStyle(.plain)
    }
}
