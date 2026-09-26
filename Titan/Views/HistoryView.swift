import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query(sort: \SupplementLog.date, order: .reverse) private var supLogs: [SupplementLog]
    @Query(sort: \Routine.orderIndex) private var routines: [Routine]

    @State private var month: Date = Date()
    @State private var selectedDay: Date?
    @State private var pendingDelete: Workout?
    @State private var savedRoutineName: String?

    private let cal = Calendar.current

    var body: some View {
        let done = workouts.filter { $0.endedAt != nil }
        let monthWorkouts = done.filter { cal.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle("HISTORY") {
                        StreakPill(days: Stats.streak(done), showLabel: false)
                    }

                    calendarCard(done)

                    monthSummary(monthWorkouts)

                    feed(monthWorkouts)
                }
                .padding(.horizontal, Layout.screenPad)
                .padding(.bottom, Layout.tabBarClearance)
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Delete this workout?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete Workout", role: .destructive) {
                    if let w = pendingDelete { delete(w) }
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Its sets, records and XP come off your log. This can't be undone.")
            }
            .alert("Saved as a routine", isPresented: Binding(get: { savedRoutineName != nil }, set: { if !$0 { savedRoutineName = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\"\(savedRoutineName ?? "")\" is in your routines, ready to run again.")
            }
        }
    }

    // MARK: Calendar

    private func calendarCard(_ done: [Workout]) -> some View {
        let trainedDays = Set(done.map { cal.startOfDay(for: $0.startedAt) })
        let supplementDays = Set(supLogs.map { cal.startOfDay(for: $0.date) })
        let isCurrentMonth = cal.isDate(month, equalTo: Date(), toGranularity: .month)
        return VStack(spacing: 10) {
            HStack {
                monthButton("chevron.left", label: "Previous month") {
                    changeMonth(by: -1)
                }
                Spacer()
                Text(Fmt.monthYear(month).uppercased())
                    .font(.condensed(21, weight: .bold))
                    .kerning(1.8)
                    .foregroundStyle(Color.textMain)
                Spacer()
                monthButton("chevron.right", label: "Next month") {
                    changeMonth(by: 1)
                }
                .opacity(isCurrentMonth ? 0.3 : 1)
                .disabled(isCurrentMonth)
            }

            let symbols = ["S", "M", "T", "W", "T", "F", "S"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[i])
                        .font(.barlow(11.5, weight: .bold))
                        .foregroundStyle(Color.textFaint)
                }
                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, cell in
                    dayCell(cell, trained: trainedDays, supplements: supplementDays)
                }
            }

            HStack(spacing: 16) {
                legendSwatch(fill: AnyShapeStyle(Color.purplePrimary.opacity(0.3)), border: Color.purplePrimary.opacity(0.55), label: "Trained")
                legendSwatch(fill: AnyShapeStyle(Color.clear), border: Color.purpleBright, label: "Today")
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.successGreen)
                        .frame(width: 6, height: 6)
                    Text("Supplements")
                        .font(.barlow(12))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(14)
        .card(20)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    // Horizontal swipes page months; vertical drags keep scrolling.
                    let dx = value.translation.width
                    guard abs(dx) > abs(value.translation.height) * 1.5 else { return }
                    if dx < -60 && !isCurrentMonth {
                        changeMonth(by: 1)
                    } else if dx > 60 {
                        changeMonth(by: -1)
                    }
                }
        )
    }

    private func monthButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.textSoft)
                .frame(width: Layout.minTap, height: Layout.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }

    private func changeMonth(by delta: Int) {
        guard let next = cal.date(byAdding: .month, value: delta, to: month) else { return }
        if delta > 0 && next > Date() && !cal.isDate(next, equalTo: Date(), toGranularity: .month) { return }
        withAnimation(.snappy) {
            month = next
            selectedDay = nil
        }
        Haptics.selection()
    }

    private var dayCells: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let dayCount = cal.range(of: .day, in: .month, for: month)?.count else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start) // 1 = Sunday
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for d in 0..<dayCount {
            cells.append(cal.date(byAdding: .day, value: d, to: interval.start))
        }
        return cells
    }

    @ViewBuilder
    private func dayCell(_ date: Date?, trained: Set<Date>, supplements: Set<Date>) -> some View {
        if let date {
            let day = cal.startOfDay(for: date)
            let isTrained = trained.contains(day)
            let isSelected = day == selectedDay
            let isToday = cal.isDateInToday(day)
            let isFuture = day > Date()
            Button {
                withAnimation(.snappy) {
                    selectedDay = isSelected ? nil : day
                }
                Haptics.selection()
            } label: {
                Text("\(cal.component(.day, from: date))")
                    .font(.condensed(16, weight: isTrained || isSelected || isToday ? .bold : .medium))
                    .foregroundStyle(cellText(trained: isTrained, selected: isSelected, today: isToday, future: isFuture))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(cellBackground(trained: isTrained, selected: isSelected))
                    .overlay(cellBorder(trained: isTrained, selected: isSelected, today: isToday))
                    .overlay(alignment: .bottom) {
                        if supplements.contains(day) {
                            Circle()
                                .fill(isSelected ? Color.white : Color.successGreen)
                                .frame(width: 5, height: 5)
                                .offset(y: -4)
                        }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isFuture)
            .accessibilityLabel("\(Fmt.dayLabel(day))\(isTrained ? ", trained" : "")")
        } else {
            Color.clear.frame(height: 42)
        }
    }

    private func cellText(trained: Bool, selected: Bool, today: Bool, future: Bool) -> Color {
        if selected { return .white }
        if today { return .purpleBright }
        if trained { return .textMain }
        return future ? .textFaint.opacity(0.5) : .textFaint
    }

    @ViewBuilder
    private func cellBackground(trained: Bool, selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentGradient)
                .shadow(color: Color.purplePrimary.opacity(0.5), radius: 8)
        } else if trained {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.purplePrimary.opacity(0.26))
        }
    }

    @ViewBuilder
    private func cellBorder(trained: Bool, selected: Bool, today: Bool) -> some View {
        if today && !selected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.purpleBright, lineWidth: 1.5)
        } else if trained && !selected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.purplePrimary.opacity(0.5), lineWidth: 1)
        }
    }

    private func legendSwatch(fill: AnyShapeStyle, border: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .frame(width: 11, height: 11)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(border, lineWidth: 1.5))
            Text(label)
                .font(.barlow(12))
                .foregroundStyle(Color.textDim)
        }
    }

    // MARK: Month summary

    @ViewBuilder
    private func monthSummary(_ monthWorkouts: [Workout]) -> some View {
        if !monthWorkouts.isEmpty && selectedDay == nil {
            let volume = monthWorkouts.reduce(0.0) { $0 + Stats.volume($1) }
            let prs = monthWorkouts.reduce(0) { $0 + Stats.prSets($1).count }
            let time = monthWorkouts.reduce(0.0) { $0 + $1.duration }
            HStack(spacing: 0) {
                summaryStat("\(monthWorkouts.count)", "WORKOUTS")
                summaryStat(Fmt.volumeK(volume), "\(Fmt.unitLabel.uppercased()) LIFTED")
                summaryStat(Fmt.hours(time), "TRAINING")
                summaryStat("\(prs)", Brand.recordsTile.uppercased(), glow: prs > 0)
            }
            .padding(.vertical, 14)
            .card(18)
        }
    }

    private func summaryStat(_ value: String, _ label: String, glow: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.condensed(22, weight: .bold))
                .foregroundStyle(glow ? Color.glow : Color.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.barlow(10.5, weight: .bold))
                .kerning(1)
                .foregroundStyle(Color.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Feed

    @ViewBuilder
    private func feed(_ monthWorkouts: [Workout]) -> some View {
        if let day = selectedDay {
            let dayWorkouts = monthWorkouts.filter { cal.isDate($0.startedAt, inSameDayAs: day) }
            HStack {
                SectionLabel(Fmt.dayLabel(day))
                Spacer()
                Button {
                    withAnimation(.snappy) { selectedDay = nil }
                } label: {
                    Text("Show whole month")
                        .font(.barlow(13.5, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                        .frame(minHeight: Layout.minTap)
                }
                .buttonStyle(.plain)
            }
            if dayWorkouts.isEmpty {
                EmptyStateCard(systemIcon: "moon.zzz", title: "Rest day", message: "Muscles grow between sessions, not during them.")
            } else {
                ForEach(dayWorkouts) { workoutCard($0) }
            }
            daySupplementsCard(day)
        } else if monthWorkouts.isEmpty {
            EmptyStateCard(
                systemIcon: "calendar",
                title: "Nothing logged in \(Fmt.monthYear(month))",
                message: "Finished workouts show up here, with every set you logged."
            )
        } else {
            SectionLabel("Workouts")
            ForEach(monthWorkouts) { workoutCard($0) }
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        let prs = Stats.prSets(workout).count
        let entries = workout.sortedEntries
        return NavigationLink {
            WorkoutDetailView(workout: workout)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Fmt.dayLabel(workout.startedAt).uppercased())
                            .font(.barlow(11.5, weight: .bold))
                            .kerning(1.4)
                            .foregroundStyle(Color.purpleBright)
                        Text(workout.title)
                            .font(.condensed(23, weight: .bold))
                            .foregroundStyle(Color.textMain)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.textFaint)
                        .padding(.top, 6)
                }

                HStack(spacing: 16) {
                    miniStat(Fmt.duration(workout.duration), icon: "clock")
                    miniStat("\(Fmt.volumeK(Stats.volume(workout))) \(Fmt.unitLabel)", icon: "scalemass")
                    miniStat("\(Stats.completedSetCount(workout)) sets", icon: "square.stack.3d.up")
                    if prs > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                            Text("\(prs)")
                                .font(.barlow(13, weight: .bold))
                        }
                        .foregroundStyle(Color.glow)
                    }
                }
                .padding(.top, 8)

                if !entries.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(entries.prefix(4).enumerated()), id: \.offset) { _, entry in
                            HStack(spacing: 8) {
                                Text(entry.displayName)
                                    .font(.barlow(14.5, weight: .medium))
                                    .foregroundStyle(Color.textSoft)
                                    .lineLimit(1)
                                if entry.sets.contains(where: { $0.isPR && $0.isCompleted }) {
                                    PRBadge(filled: true)
                                }
                                Spacer(minLength: 6)
                                Text(entrySummary(entry))
                                    .font(.barlow(13.5, weight: .semibold))
                                    .foregroundStyle(Color.textDim)
                                    .lineLimit(1)
                            }
                        }
                        if entries.count > 4 {
                            Text("+\(entries.count - 4) more")
                                .font(.barlow(13))
                                .foregroundStyle(Color.textFaint)
                        }
                    }
                    .padding(.top, 12)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.hairline).frame(height: 1).offset(y: 5)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(20)
        }
        .buttonStyle(.pressable)
        .contextMenu {
            Button {
                repeatWorkout(workout)
            } label: {
                Label("Do this workout again", systemImage: "arrow.clockwise")
            }
            Button {
                let r = WorkoutBuilder.saveAsRoutine(workout, context: context, routines: routines)
                savedRoutineName = r.name
                Haptics.success()
            } label: {
                Label("Save as routine", systemImage: "square.and.arrow.down")
            }
            Button(role: .destructive) {
                pendingDelete = workout
            } label: {
                Label("Delete workout", systemImage: "trash")
            }
        }
    }

    private func miniStat(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.barlow(13, weight: .semibold))
        }
        .foregroundStyle(Color.textDim)
    }

    private func entrySummary(_ entry: WorkoutEntry) -> String {
        let n = entry.completedSets.count
        if entry.isDuration {
            return "\(entry.completedSets.reduce(0) { $0 + $1.reps }) min"
        }
        let top = entry.workingSets.max { a, b in a.weight == b.weight ? a.reps < b.reps : a.weight < b.weight }
        let setsText = "\(n) set\(n == 1 ? "" : "s")"
        if let top, top.weight > 0 {
            return "\(setsText) · \(Fmt.weight(top.weight))×\(top.reps)"
        }
        return setsText
    }

    // MARK: Supplements for a day

    @ViewBuilder
    private func daySupplementsCard(_ day: Date) -> some View {
        let totals = supplementTotals(for: day)
        if !totals.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("Supplements")
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                ForEach(Array(totals.enumerated()), id: \.offset) { i, s in
                    HStack {
                        Circle()
                            .fill(Color.successGreen)
                            .frame(width: 6, height: 6)
                        Text(s.name)
                            .font(.barlow(15, weight: .medium))
                            .foregroundStyle(Color.textMain)
                        Spacer()
                        Text("\(Fmt.num(s.amount)) \(s.unit)")
                            .font(.condensed(19, weight: .bold))
                            .foregroundStyle(Color.textSoft)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    if i < totals.count - 1 {
                        Divider().overlay(Color.hairlineSoft).padding(.leading, 16)
                    }
                }
            }
            .padding(.bottom, 4)
            .card(18)
        }
    }

    private func supplementTotals(for day: Date) -> [(name: String, amount: Double, unit: String)] {
        let logs = supLogs.filter { cal.isDate($0.date, inSameDayAs: day) }
        var totals: [(name: String, amount: Double, unit: String)] = []
        for (name, group) in Dictionary(grouping: logs, by: { $0.name }) {
            let amount = group.reduce(0.0) { $0 + $1.amount }
            totals.append((name, amount, group.first?.unit ?? ""))
        }
        return totals.sorted { $0.name < $1.name }
    }

    // MARK: Actions

    private func repeatWorkout(_ workout: Workout) {
        guard app.activeWorkout == nil else {
            app.workoutPresented = true
            return
        }
        let w = WorkoutBuilder.repeatWorkout(workout, context: context, history: workouts)
        app.activeWorkout = w
        app.showSummary = false
        app.workoutPresented = true
        Haptics.medium()
    }

    private func delete(_ workout: Workout) {
        let since = workout.startedAt
        let remaining = workouts.filter { $0 !== workout }
        withAnimation(.snappy) {
            context.delete(workout)
        }
        // Later records were measured against this workout.
        Stats.recomputePRs(since: since, all: remaining)
        try? context.save()
        pendingDelete = nil
        Haptics.warning()
    }
}
