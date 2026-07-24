import SwiftUI
import SwiftData

// MARK: - Program detail (adopt a popular program)

struct ProgramDetailView: View {
    let program: Program

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var showConfirm = false
    @State private var adopted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                BackHeader(label: "Routines") { dismiss() }

                Text(program.name.uppercased())
                    .font(.condensed(32, weight: .heavy))
                    .kerning(1)
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(program.blurb)
                    .font(.barlow(13.5))
                    .lineSpacing(4)
                    .foregroundStyle(Color.textDim)

                ForEach(Array(program.days.enumerated()), id: \.offset) { i, day in
                    dayCard(index: i, day: day)
                }

                if adopted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.successGreen)
                        Text("Added to your routines and set as your split")
                            .font(.barlow(13, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .card(14, border: Color.successGreen.opacity(0.35))
                } else {
                    GradientCTA("USE THIS PROGRAM") {
                        showConfirm = true
                    }
                    .padding(.top, 8)
                    Text("Copies these \(program.days.count) days into your routines and makes them your split. Your existing routines aren't touched.")
                        .font(.barlow(11.5))
                        .foregroundStyle(Color.textFaint)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Use \(program.name)?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Set As My Split") {
                ProgramLibrary.adopt(program, context: context, routines: routines, exercises: exercises)
                adopted = true
                Haptics.success()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Adds \(program.days.count) routines and replaces your current split rotation.")
        }
    }

    private func dayCard(index: Int, day: ProgramDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DAY \(index + 1)")
                    .font(.barlow(9.5, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.purpleBright)
                Text(day.name.uppercased())
                    .font(.condensed(18, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Text("\(day.items.count) exercises")
                    .font(.barlow(11))
                    .foregroundStyle(Color.textFaint)
            }
            VStack(spacing: 6) {
                ForEach(Array(day.items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.name)
                            .font(.barlow(13, weight: .medium))
                            .foregroundStyle(Color.textSoft)
                        Spacer()
                        Text(repLabel(item))
                            .font(.condensed(15, weight: .semibold))
                            .foregroundStyle(Color.textDim)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func repLabel(_ item: ProgramItem) -> String {
        if item.low == item.high {
            return "\(item.sets) × \(item.low)"
        }
        return "\(item.sets) × \(item.low)–\(item.high)"
    }
}

// MARK: - Split editor

struct SplitEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]

    private var scheduled: [Routine] {
        routines
            .filter { $0.scheduleIndex != nil }
            .sorted { ($0.scheduleIndex ?? 0) < ($1.scheduleIndex ?? 0) }
    }

    private var unscheduled: [Routine] {
        routines.filter { $0.scheduleIndex == nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Color.clear.frame(width: 50, height: 1)
                Spacer()
                Text("MY SPLIT")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Done") {
                    try? context.save()
                    dismiss()
                }
                .font(.barlow(14, weight: .semibold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 6)

            List {
                Section {
                    if scheduled.isEmpty {
                        Text("Nothing in your split yet — add routines below.")
                            .font(.barlow(12.5))
                            .foregroundStyle(Color.textDim)
                            .listRowBackground(Color.surface)
                    }
                    ForEach(scheduled) { routine in
                        HStack(spacing: 12) {
                            Text("DAY \((routine.scheduleIndex ?? 0) + 1)")
                                .font(.condensed(14, weight: .bold))
                                .kerning(1)
                                .foregroundStyle(Color.purpleBright)
                                .frame(width: 52, alignment: .leading)
                            Text(routine.name)
                                .font(.barlow(14, weight: .semibold))
                                .foregroundStyle(Color.textMain)
                            Spacer()
                            Button {
                                remove(routine)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.dangerRed.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.surface)
                    }
                    .onMove(perform: move)
                } header: {
                    Text("ROTATION · HOLD & DRAG TO REORDER")
                        .font(.barlow(10.5, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textDim)
                }

                if !unscheduled.isEmpty {
                    Section {
                        ForEach(unscheduled) { routine in
                            HStack {
                                Text(routine.name)
                                    .font(.barlow(14, weight: .medium))
                                    .foregroundStyle(Color.textSoft)
                                Spacer()
                                Button {
                                    add(routine)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.purpleBright)
                                }
                                .buttonStyle(.plain)
                            }
                            .listRowBackground(Color.surface)
                        }
                    } header: {
                        Text("ADD TO SPLIT")
                            .font(.barlow(10.5, weight: .semibold))
                            .kerning(1.5)
                            .foregroundStyle(Color.textDim)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.sheetBg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func add(_ routine: Routine) {
        routine.scheduleIndex = (routines.compactMap { $0.scheduleIndex }.max() ?? -1) + 1
        Haptics.tap()
    }

    private func remove(_ routine: Routine) {
        routine.scheduleIndex = nil
        for (i, r) in scheduled.enumerated() {
            r.scheduleIndex = i
        }
        Haptics.tap()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = scheduled
        items.move(fromOffsets: source, toOffset: destination)
        for (i, r) in items.enumerated() {
            r.scheduleIndex = i
        }
    }
}
