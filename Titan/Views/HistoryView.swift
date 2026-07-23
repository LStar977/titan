import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query(sort: \SupplementLog.date, order: .reverse) private var supLogs: [SupplementLog]

    @State private var month: Date = Date()
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }
    private let cal = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("HISTORY")
                            .font(.condensed(36, weight: .heavy))
                            .kerning(2)
                            .foregroundStyle(Color.textMain)
                        Spacer()
                        StreakPill(days: Stats.streak(finished), showLabel: false)
                    }
                    .padding(.top, 6)

                    calendarCard

                    daySummary
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Calendar

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month).uppercased()
    }

    private var trainedDays: Set<Date> {
        Set(finished.map { cal.startOfDay(for: $0.startedAt) })
    }

    private var supplementDays: Set<Date> {
        Set(supLogs.map { cal.startOfDay(for: $0.date) })
    }

    private var calendarCard: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    month = cal.date(byAdding: .month, value: -1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textDim)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text(monthTitle)
                    .font(.condensed(19, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button {
                    month = cal.date(byAdding: .month, value: 1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.textFaint)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            let symbols = ["S", "M", "T", "W", "T", "F", "S"]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[i])
                        .font(.barlow(9.5, weight: .bold))
                        .foregroundStyle(Color.textFaint)
                }
                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, cell in
                    dayCell(cell)
                }
            }

            HStack(spacing: 14) {
                legend(fill: AnyShapeStyle(Color.purplePrimary.opacity(0.35)), border: Color.purplePrimary.opacity(0.55), label: "Trained")
                legend(fill: AnyShapeStyle(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom)), border: .clear, label: "Selected")
                legend(fill: AnyShapeStyle(Color.clear), border: Color.purpleBright, label: "Today")
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.successGreen)
                        .frame(width: 5, height: 5)
                    Text("Supps")
                        .font(.barlow(10))
                        .foregroundStyle(Color.textDim)
                }
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding(14)
        .card(18)
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
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            let day = cal.startOfDay(for: date)
            let trained = trainedDays.contains(day)
            let selected = day == selectedDay
            let isToday = cal.isDateInToday(day)
            Button {
                selectedDay = day
                Haptics.tap()
            } label: {
                Text("\(cal.component(.day, from: date))")
                    .font(.condensed(15, weight: trained || selected || isToday ? .semibold : .medium))
                    .foregroundStyle(cellText(trained: trained, selected: selected, isToday: isToday))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(cellBackground(trained: trained, selected: selected))
                    .overlay(cellBorder(trained: trained, selected: selected, isToday: isToday))
                    .overlay(alignment: .bottom) {
                        if supplementDays.contains(day) {
                            Circle()
                                .fill(Color.successGreen)
                                .frame(width: 4, height: 4)
                                .offset(y: -3.5)
                        }
                    }
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 38)
        }
    }

    private func cellText(trained: Bool, selected: Bool, isToday: Bool) -> Color {
        if selected { return .white }
        if isToday { return .purpleBright }
        if trained { return .textMain }
        return .textFaint
    }

    @ViewBuilder
    private func cellBackground(trained: Bool, selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 11)
                .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.purplePrimary.opacity(0.55), radius: 8)
        } else if trained {
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.purplePrimary.opacity(0.28))
        }
    }

    @ViewBuilder
    private func cellBorder(trained: Bool, selected: Bool, isToday: Bool) -> some View {
        if isToday && !selected {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.purpleBright, lineWidth: 1.5)
        } else if trained && !selected {
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.purplePrimary.opacity(0.5), lineWidth: 1)
        }
    }

    private func legend(fill: AnyShapeStyle, border: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fill)
                .frame(width: 10, height: 10)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(border, lineWidth: 1.5))
            Text(label)
                .font(.barlow(10))
                .foregroundStyle(Color.textDim)
        }
    }

    // MARK: Day summary

    private var dayWorkouts: [Workout] {
        finished.filter { cal.isDate($0.startedAt, inSameDayAs: selectedDay) }
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: selectedDay).uppercased()
    }

    @ViewBuilder
    private var daySummary: some View {
        if dayWorkouts.isEmpty {
            VStack(spacing: 6) {
                Text(dayLabel)
                    .font(.barlow(10, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.purpleBright)
                Text("Rest day")
                    .font(.condensed(20, weight: .semibold))
                    .foregroundStyle(Color.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .card(18)
        } else {
            ForEach(dayWorkouts) { workout in
                workoutCard(workout)
            }
        }
        daySupplementsCard
    }

    private var daySupplements: [(name: String, amount: Double, unit: String)] {
        let logs = supLogs.filter { cal.isDate($0.date, inSameDayAs: selectedDay) }
        var totals: [String: (amount: Double, unit: String)] = [:]
        for log in logs {
            let cur = totals[log.name]?.amount ?? 0
            totals[log.name] = (cur + log.amount, log.unit)
        }
        return totals
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.amount, $0.value.unit) }
    }

    @ViewBuilder
    private var daySupplementsCard: some View {
        let supps = daySupplements
        if !supps.isEmpty {
            VStack(spacing: 0) {
                Text("SUPPLEMENTS")
                    .font(.barlow(10.5, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 13)
                    .padding(.bottom, 9)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                    }
                ForEach(Array(supps.enumerated()), id: \.offset) { i, s in
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.successGreen)
                                .frame(width: 5, height: 5)
                            Text(s.name)
                                .font(.barlow(13.5, weight: .medium))
                                .foregroundStyle(Color.textMain)
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(Fmt.weight(s.amount))
                                .font(.condensed(18, weight: .bold))
                                .foregroundStyle(Color.textSoft)
                            Text(s.unit)
                                .font(.condensed(12, weight: .bold))
                                .foregroundStyle(Color.textFaint)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if i < supps.count - 1 {
                        Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 16)
                    }
                }
            }
            .card(18)
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(dayLabel)
                        .font(.barlow(10, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(Color.purpleBright)
                    Text(workout.title)
                        .font(.condensed(22, weight: .bold))
                        .foregroundStyle(Color.textMain)
                }
                Spacer()
                HStack(spacing: 12) {
                    miniStat(Fmt.clock(workout.duration), "TIME")
                    miniStat(Fmt.volumeK(Stats.volume(workout)), "LB VOL")
                    let prs = Stats.prSets(workout).count
                    miniStat("\(prs)", "PRS", glow: prs > 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }

            ForEach(Array(workout.sortedEntries.enumerated()), id: \.offset) { i, entry in
                NavigationLink {
                    ExerciseDetailView(exerciseName: entry.displayName)
                } label: {
                    HStack {
                        HStack(spacing: 8) {
                            Text(entry.displayName)
                                .font(.barlow(13.5, weight: .semibold))
                                .foregroundStyle(Color.textMain)
                            if entry.sets.contains(where: { $0.isPR && $0.isCompleted }) {
                                PRBadge(filled: true)
                            }
                        }
                        Spacer()
                        if let top = topSet(entry) {
                            Group {
                                Text("\(entry.completedSets.count) sets · top ")
                                    .foregroundStyle(Color.textDim)
                                + Text("\(Fmt.weight(top.weight)) × \(top.reps)")
                                    .font(.barlow(12, weight: .semibold))
                                    .foregroundStyle(Color.textSoft)
                            }
                            .font(.barlow(12))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if i < workout.entries.count - 1 {
                    Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 16)
                }
            }
        }
        .card(18)
    }

    private func topSet(_ entry: WorkoutEntry) -> SetEntry? {
        entry.completedSets
            .filter { $0.type != .warmup }
            .max { a, b in
                if a.weight != b.weight { return a.weight < b.weight }
                return a.reps < b.reps
            }
    }

    private func miniStat(_ value: String, _ label: String, glow: Bool = false) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value)
                .font(.condensed(19, weight: .bold))
                .foregroundStyle(glow ? Color.glow : Color.textMain)
                .shadow(color: glow ? Color.glow.opacity(0.5) : .clear, radius: 5)
            Text(label)
                .font(.barlow(9, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Color.textFaint)
        }
    }
}
