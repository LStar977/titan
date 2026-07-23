import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    let onDone: ([Exercise]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var search = ""
    @State private var muscleFilter: MuscleCategory = .all
    @State private var equipmentFilter: Set<Equipment> = []
    @State private var selected: Set<ObjectIdentifier> = []
    @State private var showNewExercise = false
    @State private var newExercisePrefill = ""

    private var filtered: [Exercise] {
        exercises.filter { ex in
            guard muscleFilter.contains(ex.muscle) else { return false }
            if !equipmentFilter.isEmpty && !equipmentFilter.contains(ex.equipment) { return false }
            if !search.isEmpty && !ex.name.localizedCaseInsensitiveContains(search) { return false }
            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(14, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 60, alignment: .leading)
                Spacer()
                Text("ADD EXERCISE")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button {
                    newExercisePrefill = search
                    showNewExercise = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("New")
                            .font(.barlow(14, weight: .semibold))
                    }
                    .foregroundStyle(Color.purpleBright)
                }
                .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.textDim)
                TextField("Search exercises", text: $search)
                    .font(.barlow(14))
                    .foregroundStyle(Color.textMain)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.surface2))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            // Muscle chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MuscleCategory.allCases, id: \.self) { cat in
                        let sel = muscleFilter == cat
                        Button {
                            muscleFilter = cat
                            Haptics.tap()
                        } label: {
                            Text(cat.rawValue)
                                .font(.barlow(12, weight: .semibold))
                                .foregroundStyle(sel ? .white : Color.textDim)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(
                                        sel
                                        ? AnyShapeStyle(LinearGradient(colors: [.purplePrimary, .purpleMid], startPoint: .top, endPoint: .bottom))
                                        : AnyShapeStyle(Color.surface2)
                                    )
                                )
                                .shadow(color: sel ? Color.purplePrimary.opacity(0.35) : .clear, radius: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            // Equipment chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Equipment.allCases.filter { $0 != .other }, id: \.self) { eq in
                        let sel = equipmentFilter.contains(eq)
                        Button {
                            if sel { equipmentFilter.remove(eq) } else { equipmentFilter.insert(eq) }
                            Haptics.tap()
                        } label: {
                            Text(eq.rawValue)
                                .font(.barlow(11.5, weight: .medium))
                                .foregroundStyle(sel ? Color.textSoft : Color.textDim)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(sel ? Color.purplePrimary.opacity(0.1) : Color.clear))
                                .overlay(
                                    Capsule().stroke(sel ? Color.purplePrimary.opacity(0.5) : Color.surface3, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)

            Divider().overlay(Color.hairline)

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    if showCreateRow {
                        createRow
                        Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 16)
                    }
                    ForEach(filtered) { ex in
                        exerciseRow(ex)
                        Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 16)
                    }
                }
                .padding(.bottom, 90)
            }
            .overlay(alignment: .bottom) {
                if !selected.isEmpty {
                    GradientCTA("ADD \(selected.count) EXERCISE\(selected.count == 1 ? "" : "S")", fontSize: 18) {
                        let picked = exercises.filter { selected.contains(ObjectIdentifier($0)) }
                        onDone(picked)
                        Haptics.medium()
                        dismiss()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .background(
                        LinearGradient(colors: [Color(hex: 0x10101B).opacity(0), Color(hex: 0x10101B)], startPoint: .top, endPoint: .bottom)
                    )
                }
            }
        }
        .background(Color(hex: 0x10101B).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showNewExercise) {
            NewExerciseSheet(initialName: newExercisePrefill) { created in
                selected.insert(ObjectIdentifier(created))
            }
        }
    }

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
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.purplePrimary.opacity(0.15))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.purpleBright)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("Create \"\(search.trimmingCharacters(in: .whitespaces))\"")
                        .font(.barlow(14.5, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                        .lineLimit(1)
                    Text("Add it as your own exercise")
                        .font(.barlow(11.5))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func exerciseRow(_ ex: Exercise) -> some View {
        let isSelected = selected.contains(ObjectIdentifier(ex))
        return Button {
            if isSelected { selected.remove(ObjectIdentifier(ex)) } else { selected.insert(ObjectIdentifier(ex)) }
            Haptics.tap()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.surface2)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Text(ex.equipment.abbrev)
                            .font(.condensed(13, weight: .bold))
                            .foregroundStyle(Color.textDim)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 7) {
                        Text(ex.name)
                            .font(.barlow(14.5, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                            .lineLimit(1)
                        if let best = Stats.bestSet(exerciseName: ex.name, workouts: workouts) {
                            Text("PR \(Fmt.weight(best.weight))×\(best.reps)")
                                .font(.barlow(8.5, weight: .bold))
                                .kerning(0.8)
                                .foregroundStyle(Color.glow)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.glow.opacity(0.4), lineWidth: 1))
                        }
                    }
                    Text(rowSubtitle(ex))
                        .font(.barlow(11.5))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
                if isSelected {
                    Circle()
                        .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: Color.purplePrimary.opacity(0.4), radius: 5)
                } else {
                    Circle()
                        .stroke(Color(hex: 0x3A3A4E), lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.purplePrimary.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func rowSubtitle(_ ex: Exercise) -> String {
        var parts = [ex.equipment.rawValue, ex.muscle.rawValue]
        if let last = workouts.first(where: { w in
            w.endedAt != nil && w.entries.contains { $0.displayName == ex.name && !$0.completedSets.isEmpty }
        }) {
            parts.append("last \(Fmt.shortDate(last.startedAt))")
        }
        return parts.joined(separator: " · ")
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

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(14, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                Spacer()
                Text("NEW EXERCISE")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Save") {
                    let ex = Exercise(name: name.trimmingCharacters(in: .whitespaces), equipment: equipment, muscle: muscle, isCustom: true)
                    context.insert(ex)
                    try? context.save()
                    onCreated?(ex)
                    Haptics.success()
                    dismiss()
                }
                .font(.barlow(14, weight: .bold))
                .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.textFaint : Color.purpleBright)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("EXERCISE NAME")
                    .font(.barlow(9.5, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textFaint)
                TextField("e.g. Larsen Press", text: $name)
                    .font(.condensed(22, weight: .bold))
                    .foregroundStyle(Color.textMain)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 13).fill(Color.surface2))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.08), lineWidth: 1))

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
        .padding(.horizontal, 16)
        .background(Color(hex: 0x10101B).ignoresSafeArea())
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

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(options, id: \.self) { opt in
                let sel = isSelected(opt)
                Button {
                    onTap(opt)
                    Haptics.tap()
                } label: {
                    Text(opt)
                        .font(.barlow(12, weight: .semibold))
                        .foregroundStyle(sel ? .white : Color.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(sel ? AnyShapeStyle(Color.purplePrimary) : AnyShapeStyle(Color.surface2))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
