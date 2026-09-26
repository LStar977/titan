import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    var singleSelect = false
    var title = "ADD EXERCISE"
    let onDone: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var search = ""
    @State private var muscleFilter: MuscleCategory = .all
    @State private var equipmentFilter: Set<Equipment> = []
    /// In the order they were tapped — that's the order they're added.
    @State private var selected: [ObjectIdentifier] = []
    @State private var showNewExercise = false
    @State private var newExercisePrefill = ""

    init(singleSelect: Bool = false, title: String = "ADD EXERCISE", onDone: @escaping ([Exercise]) -> Void) {
        self.singleSelect = singleSelect
        self.title = title
        self.onDone = onDone
    }

    private var isFiltering: Bool {
        !search.trimmingCharacters(in: .whitespaces).isEmpty || muscleFilter != .all || !equipmentFilter.isEmpty
    }

    private func matches(_ ex: Exercise) -> Bool {
        guard muscleFilter.contains(ex.muscle) else { return false }
        if !equipmentFilter.isEmpty && !equipmentFilter.contains(ex.equipment) { return false }
        let q = search.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty && !ex.name.localizedCaseInsensitiveContains(q) { return false }
        return true
    }

    /// Last time each exercise was trained, from one pass over history.
    private func lastDoneIndex() -> [String: Date] {
        var out: [String: Date] = [:]
        for w in workouts where w.endedAt != nil {
            for e in w.entries where out[e.displayName] == nil && !e.completedSets.isEmpty {
                out[e.displayName] = w.startedAt
            }
        }
        return out
    }

    var body: some View {
        let lastDone = lastDoneIndex()
        let best = Stats.bestSetIndex(workouts)
        let filtered = exercises.filter(matches)
        let recent: [Exercise] = isFiltering ? [] : exercises
            .filter { lastDone[$0.name] != nil }
            .sorted { (lastDone[$0.name] ?? .distantPast) > (lastDone[$1.name] ?? .distantPast) }
            .prefix(8)
            .map { $0 }

        return VStack(spacing: 0) {
            header
            searchField
            muscleChips
            equipmentChips
            Divider().overlay(Color.hairline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if showCreateRow {
                        createRow
                        Divider().overlay(Color.hairlineSoft).padding(.leading, 70)
                    }
                    if !recent.isEmpty {
                        listLabel("Recent")
                        ForEach(recent) { ex in
                            exerciseRow(ex, lastDone: lastDone[ex.name], best: best[ex.name])
                            Divider().overlay(Color.hairlineSoft).padding(.leading, 70)
                        }
                        listLabel("All exercises")
                    }
                    ForEach(filtered) { ex in
                        exerciseRow(ex, lastDone: lastDone[ex.name], best: best[ex.name])
                        Divider().overlay(Color.hairlineSoft).padding(.leading, 70)
                    }
                    if filtered.isEmpty && !showCreateRow {
                        Text("No exercises match those filters.")
                            .font(.barlow(15))
                            .foregroundStyle(Color.textDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottom) {
                if !singleSelect && !selected.isEmpty {
                    GradientCTA("ADD \(selected.count) EXERCISE\(selected.count == 1 ? "" : "S")", fontSize: 18) {
                        commit()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
                    .padding(.top, 24)
                    .background(
                        LinearGradient(colors: [Color.sheetBg.opacity(0), Color.sheetBg], startPoint: .top, endPoint: .bottom)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Color.sheetBg.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showNewExercise) {
            NewExerciseSheet(initialName: newExercisePrefill) { created in
                if singleSelect {
                    onDone([created])
                    dismiss()
                } else if !selected.contains(ObjectIdentifier(created)) {
                    selected.append(ObjectIdentifier(created))
                }
            }
        }
    }

    // MARK: Header & filters

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.barlow(16, weight: .medium))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Text(title)
                .font(.condensed(20, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Color.textMain)
            Spacer()
            Button {
                newExercisePrefill = search.trimmingCharacters(in: .whitespaces)
                showNewExercise = true
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("New")
                        .font(.barlow(16, weight: .semibold))
                }
                .foregroundStyle(Color.purpleBright)
                .frame(minHeight: Layout.minTap)
            }
            .frame(width: 70, alignment: .trailing)
            .accessibilityLabel("Create a new exercise")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(Color.textDim)
            TextField("Search exercises", text: $search)
                .font(.barlow(16))
                .foregroundStyle(Color.textMain)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.textFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.surface2))
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private var muscleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(MuscleCategory.allCases, id: \.self) { cat in
                    let sel = muscleFilter == cat
                    Button {
                        withAnimation(.snappy) { muscleFilter = cat }
                        Haptics.selection()
                    } label: {
                        Text(cat.rawValue)
                            .font(.barlow(14, weight: .semibold))
                            .foregroundStyle(sel ? Color.white : Color.textDim)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(
                                Capsule().fill(sel ? AnyShapeStyle(Color.accentGradient) : AnyShapeStyle(Color.surface2))
                            )
                            .shadow(color: sel ? Color.purplePrimary.opacity(0.3) : .clear, radius: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 8)
    }

    private var equipmentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Equipment.allCases.filter { $0 != .other }, id: \.self) { eq in
                    let sel = equipmentFilter.contains(eq)
                    Button {
                        if sel { equipmentFilter.remove(eq) } else { equipmentFilter.insert(eq) }
                        Haptics.selection()
                    } label: {
                        Text(eq.rawValue)
                            .font(.barlow(13, weight: .medium))
                            .foregroundStyle(sel ? Color.textMain : Color.textDim)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Capsule().fill(sel ? Color.purplePrimary.opacity(0.12) : Color.clear))
                            .overlay(Capsule().stroke(sel ? Color.purplePrimary.opacity(0.55) : Color.surface3, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 12)
    }

    private func listLabel(_ text: String) -> some View {
        SectionLabel(text)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    // MARK: Rows

    /// Offer to create exactly what the athlete typed when nothing matches it.
    private var showCreateRow: Bool {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return false }
        return !exercises.contains { $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame }
    }

    private var createRow: some View {
        Button {
            newExercisePrefill = search.trimmingCharacters(in: .whitespaces)
            showNewExercise = true
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.purplePrimary.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.purpleBright)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create \"\(search.trimmingCharacters(in: .whitespaces))\"")
                        .font(.barlow(16, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                        .lineLimit(1)
                    Text("Add it as your own exercise")
                        .font(.barlow(13))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func exerciseRow(_ ex: Exercise, lastDone: Date?, best: (weight: Double, reps: Int)?) -> some View {
        let order = selected.firstIndex(of: ObjectIdentifier(ex))
        let isSelected = order != nil
        return Button {
            toggle(ex)
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.surface2)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(ex.equipment.abbrev)
                            .font(.condensed(14, weight: .bold))
                            .foregroundStyle(Color.textDim)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text(ex.name)
                            .font(.barlow(16, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                            .lineLimit(1)
                        if let best {
                            Text("PR \(Fmt.weight(best.weight))×\(best.reps)")
                                .font(.barlow(11, weight: .bold))
                                .kerning(0.6)
                                .foregroundStyle(Color.glow)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.glow.opacity(0.4), lineWidth: 1))
                        }
                    }
                    Text(rowSubtitle(ex, lastDone: lastDone))
                        .font(.barlow(13))
                        .foregroundStyle(Color.textDim)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if singleSelect {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textFaint)
                } else if let order {
                    Text("\(order + 1)")
                        .font(.condensed(15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.accentGradient))
                        .shadow(color: Color.purplePrimary.opacity(0.4), radius: 5)
                } else {
                    Circle()
                        .stroke(Color.outline, lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 64)
            .background(isSelected ? Color.purplePrimary.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func rowSubtitle(_ ex: Exercise, lastDone: Date?) -> String {
        var parts = [ex.equipment.rawValue, ex.muscle.rawValue]
        if let lastDone {
            parts.append("last \(Fmt.relative(lastDone).lowercased())")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Actions

    private func toggle(_ ex: Exercise) {
        if singleSelect {
            onDone([ex])
            Haptics.medium()
            dismiss()
            return
        }
        let id = ObjectIdentifier(ex)
        withAnimation(.snappy) {
            if let i = selected.firstIndex(of: id) {
                selected.remove(at: i)
            } else {
                selected.append(id)
            }
        }
        Haptics.selection()
    }

    private func commit() {
        let byID = Dictionary(exercises.map { (ObjectIdentifier($0), $0) }, uniquingKeysWith: { a, _ in a })
        let picked = selected.compactMap { byID[$0] }
        onDone(picked)
        Haptics.medium()
        dismiss()
    }
}

// MARK: - New custom exercise

struct NewExerciseSheet: View {
    var initialName: String = ""
    var onCreated: ((Exercise) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var equipment: Equipment = .barbell
    @State private var muscle: Muscle = .chest

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(16, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                Spacer()
                Text("NEW EXERCISE")
                    .font(.condensed(20, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Save") {
                    let ex = Exercise(name: trimmed, equipment: equipment, muscle: muscle, isCustom: true)
                    context.insert(ex)
                    try? context.save()
                    onCreated?(ex)
                    Haptics.success()
                    dismiss()
                }
                .font(.barlow(16, weight: .bold))
                .foregroundStyle(trimmed.isEmpty ? Color.textFaint : Color.purpleBright)
                .disabled(trimmed.isEmpty)
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("EXERCISE NAME")
                    .font(.barlow(11, weight: .bold))
                    .kerning(1.4)
                    .foregroundStyle(Color.textFaint)
                TextField("e.g. Larsen Press", text: $name)
                    .font(.condensed(24, weight: .bold))
                    .foregroundStyle(Color.textMain)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.surface2))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.strokeStrong, lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Equipment")
                FlowChips(
                    options: Equipment.allCases.map { $0.rawValue },
                    isSelected: { $0 == equipment.rawValue },
                    onTap: { if let e = Equipment(rawValue: $0) { equipment = e } }
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Primary muscle")
                FlowChips(
                    options: Muscle.allCases.map { $0.rawValue },
                    isSelected: { $0 == muscle.rawValue },
                    onTap: { if let m = Muscle(rawValue: $0) { muscle = m } }
                )
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .background(Color.sheetBg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if name.isEmpty { name = initialName }
        }
    }
}

/// Simple wrapping chip grid.
struct FlowChips: View {
    let options: [String]
    let isSelected: (String) -> Bool
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 7)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
            ForEach(options, id: \.self) { opt in
                let sel = isSelected(opt)
                Button {
                    onTap(opt)
                    Haptics.selection()
                } label: {
                    Text(opt)
                        .font(.barlow(13.5, weight: .semibold))
                        .foregroundStyle(sel ? Color.white : Color.textDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            Capsule().fill(sel ? AnyShapeStyle(Color.purplePrimary) : AnyShapeStyle(Color.surface2))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
