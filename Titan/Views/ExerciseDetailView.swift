import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    let exerciseName: String
    var asSheet = false

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var exercises: [Exercise]

    @State private var selectedWorkout: Workout?

    private var exercise: Exercise? {
        exercises.first { $0.name == exerciseName }
    }

    private var isDuration: Bool { exercise?.muscle.isDuration ?? false }

    /// Newest-first sessions of this exercise that have logged sets.
    private func sessions() -> [ExerciseSession] {
        let duration = isDuration
        return workouts.compactMap { w in
            guard w.endedAt != nil else { return nil }
            let sets = w.sortedEntries
                .filter { $0.displayName == exerciseName }
                .flatMap { duration ? $0.completedSets : $0.workingSets }
            return sets.isEmpty ? nil : ExerciseSession(workout: w, sets: sets)
        }
    }

    var body: some View {
        let list = sessions()
        let chart = chartData(list)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                topBar
                titleBlock(list)
                if list.isEmpty {
                    EmptyStateCard(
                        systemIcon: "chart.line.uptrend.xyaxis",
                        title: "No sessions yet",
                        message: "Log \(exerciseName) once and its history starts here."
                    )
                } else {
                    if isDuration {
                        durationStats(list)
                    } else {
                        strengthStats(list)
                    }
                    if chart.points.count > 1 {
                        chartCard(chart)
                    }
                    if !isDuration {
                        repMaxCard
                    }
                    historyCard(list)
                }
            }
            .padding(.horizontal, Layout.screenPad)
            .padding(.bottom, asSheet ? 40 : Layout.tabBarClearance)
        }
        .background((asSheet ? Color.sheetBg : Color.bg).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedWorkout) { workout in
            NavigationStack {
                WorkoutDetailView(workout: workout, asSheet: true)
            }
        }
    }

    // MARK: Header

    @ViewBuilder
    private var topBar: some View {
        if asSheet {
            HStack {
                Text("EXERCISE")
                    .font(.condensed(20, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.barlow(16, weight: .semibold))
                    .foregroundStyle(Color.purpleBright)
                    .frame(minHeight: Layout.minTap)
            }
            .padding(.top, 12)
        } else {
            BackHeader(label: "Back") { dismiss() }
        }
    }

    private func titleBlock(_ list: [ExerciseSession]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exerciseName.uppercased())
                .font(.condensed(34, weight: .heavy))
                .kerning(1)
                .foregroundStyle(Color.textMain)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(subtitle(list))
                .font(.barlow(12.5, weight: .semibold))
                .kerning(1.4)
                .foregroundStyle(Color.textDim)
        }
    }

    private func subtitle(_ list: [ExerciseSession]) -> String {
        var parts: [String] = []
        if let ex = exercise {
            parts.append(ex.equipment.rawValue.uppercased())
            parts.append(ex.muscle.rawValue.uppercased())
        }
        parts.append("\(list.count) SESSION\(list.count == 1 ? "" : "S")")
        return parts.joined(separator: " · ")
    }

    // MARK: Stats

    private func strengthStats(_ list: [ExerciseSession]) -> some View {
        let all = list.flatMap { $0.sets }
        let load = tracksLoad(list)
        let best = all.filter { $0.weight > 0 }.map { Stats.e1RM($0.weight, $0.reps) }.max() ?? 0
        let lifetime = all.reduce(0.0) { $0 + Stats.setVolume($1) }
        let bestSet = Stats.bestSet(exerciseName: exerciseName, workouts: workouts)
        let mostReps = all.filter { $0.weight == 0 }.map { $0.reps }.max() ?? (all.map { $0.reps }.max() ?? 0)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(load ? "EST. 1RM" : "MOST REPS")
                    .font(.barlow(11, weight: .semibold))
                    .kerning(1.4)
                    .foregroundStyle(Color.glow)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(load ? Fmt.whole(best) : "\(mostReps)")
                        .font(.condensed(32, weight: .bold))
                        .foregroundStyle(Color.glow)
                        .brandGlow(Color.glow.opacity(0.5), radius: 6)
                    if load {
                        Text(Fmt.unitLabel)
                            .font(.condensed(16, weight: .bold))
                            .foregroundStyle(Color.textDim)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .card(16, border: Color.glow.opacity(0.35))

            smallStat("BEST SET", bestSet.map { "\(Fmt.weight($0.weight))×\($0.reps)" } ?? "—")
            smallStat("LIFETIME", "\(Fmt.volumeK(lifetime))")
        }
    }

    private func durationStats(_ list: [ExerciseSession]) -> some View {
        let minutes = list.map { $0.sets.reduce(0) { $0 + $1.reps } }
        return HStack(spacing: 10) {
            smallStat("TOTAL", "\(minutes.reduce(0, +)) min")
            smallStat("LONGEST", "\(minutes.max() ?? 0) min")
            smallStat("SESSIONS", "\(list.count)")
        }
    }

    private func smallStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.barlow(11, weight: .semibold))
                .kerning(1.4)
                .foregroundStyle(Color.textDim)
            Text(value)
                .font(.condensed(26, weight: .bold))
                .foregroundStyle(Color.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .card(16)
    }

    // MARK: Chart

    /// Whether this lift is measured by estimated 1RM or — for bodyweight work
    /// done mostly without added weight — by reps. Decided once, so the header
    /// and chart never mix the two scales.
    private func tracksLoad(_ list: [ExerciseSession]) -> Bool {
        guard !isDuration else { return false }
        let recent = list.prefix(24)
        let loaded = recent.filter { s in s.sets.contains { $0.weight > 0 } }.count
        return loaded > 0 && loaded * 2 >= recent.count
    }

    /// The last 24 sessions, oldest first, all on the one scale. Sessions with
    /// nothing on that scale are left out rather than plotted as zero.
    private func chartData(_ list: [ExerciseSession]) -> (points: [SessionPoint], load: Bool) {
        let unit = Fmt.unit
        let load = tracksLoad(list)
        let points: [SessionPoint] = list.prefix(24).reversed().compactMap { s in
            let value: Double
            if isDuration {
                value = Double(s.sets.reduce(0) { $0 + $1.reps })
            } else if load {
                value = unit.fromLb(s.sets.filter { $0.weight > 0 }.map { Stats.e1RM($0.weight, $0.reps) }.max() ?? 0)
            } else {
                value = Double(s.sets.filter { $0.weight == 0 }.map { $0.reps }.max() ?? 0)
            }
            guard value > 0 else { return nil }
            return SessionPoint(date: s.workout.startedAt, value: value, isPR: s.sets.contains { $0.isPR })
        }
        return (points: points, load: load)
    }

    private func chartCard(_ chart: (points: [SessionPoint], load: Bool)) -> some View {
        let points = chart.points
        let lo = points.map { $0.value }.min() ?? 0
        let hi = points.map { $0.value }.max() ?? 1
        let pad = max((hi - lo) * 0.15, hi * 0.03, 1)
        let yMin = max(0, lo - pad)
        let yMax = hi + pad

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(isDuration ? "Minutes per session" : (chart.load ? "Estimated 1RM" : "Best reps"))
                Spacer()
                Text("Last \(points.count) sessions")
                    .font(.barlow(12.5))
                    .foregroundStyle(Color.textFaint)
            }
            Chart(points) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    yStart: .value("Floor", yMin),
                    yEnd: .value("Value", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(colors: [Color.purplePrimary.opacity(0.32), Color.purplePrimary.opacity(0)], startPoint: .top, endPoint: .bottom)
                )
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Value", p.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.purplePrimary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Value", p.value)
                )
                .foregroundStyle(p.isPR ? Color.glow : Color.purplePrimary)
                .symbolSize(p.isPR ? 80 : 26)
            }
            .chartYScale(domain: yMin...yMax)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Color.textFaint)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.hairline)
                    AxisValueLabel()
                        .foregroundStyle(Color.textFaint)
                }
            }
            .frame(height: 190)

            if points.contains(where: { $0.isPR }) {
                HStack(spacing: 6) {
                    Circle().fill(Color.glow).frame(width: 8, height: 8)
                    Text("Sessions with a record")
                        .font(.barlow(12.5))
                        .foregroundStyle(Color.textDim)
                }
            }
        }
        .padding(16)
        .card(20)
    }

    // MARK: Rep maxes

    @ViewBuilder
    private var repMaxCard: some View {
        let maxes = Stats.repMaxes(exerciseName: exerciseName, workouts: workouts)
        if !maxes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Rep maxes")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(maxes) { rm in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(rm.reps) REP\(rm.reps == 1 ? "" : "S")")
                                .font(.barlow(11, weight: .bold))
                                .kerning(1.2)
                                .foregroundStyle(Color.purpleBright)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(Fmt.weight(rm.weight))
                                    .font(.condensed(24, weight: .bold))
                                    .foregroundStyle(Color.textMain)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text(Fmt.unitLabel)
                                    .font(.condensed(13, weight: .bold))
                                    .foregroundStyle(Color.textDim)
                            }
                            Text(Fmt.shortDate(rm.date))
                                .font(.barlow(11.5))
                                .foregroundStyle(Color.textFaint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.surface2))
                    }
                }
                Text("The heaviest weight you've moved for at least that many reps.")
                    .font(.barlow(12.5))
                    .foregroundStyle(Color.textDim)
            }
            .padding(16)
            .card(20)
        }
    }

    // MARK: History

    private func historyCard(_ list: [ExerciseSession]) -> some View {
        VStack(spacing: 0) {
            SectionLabel("History")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            Rectangle().fill(Color.hairline).frame(height: 1)

            ForEach(Array(list.enumerated()), id: \.offset) { i, session in
                Button {
                    selectedWorkout = session.workout
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 7) {
                                Text("\(Fmt.shortDate(session.workout.startedAt)) · \(session.workout.title)")
                                    .font(.barlow(15, weight: .semibold))
                                    .foregroundStyle(Color.textMain)
                                    .lineLimit(1)
                                if session.sets.contains(where: { $0.isPR }) {
                                    PRBadge(filled: true)
                                }
                            }
                            Text(setsLine(session.sets))
                                .font(.barlow(13.5))
                                .foregroundStyle(Color.textDim)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 6)
                        Text(sessionTotal(session.sets))
                            .font(.condensed(18, weight: .bold))
                            .foregroundStyle(Color.textSoft)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.textFaint)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if i < list.count - 1 {
                    Divider().overlay(Color.hairlineSoft).padding(.leading, 16)
                }
            }
        }
        .card(18)
    }

    private func setsLine(_ sets: [SetEntry]) -> String {
        if isDuration {
            return sets.map { "\($0.reps) min" }.joined(separator: " · ")
        }
        return sets.map { s in
            s.weight > 0 ? "\(Fmt.weight(s.weight))×\(s.reps)" : "\(s.reps)"
        }.joined(separator: " · ")
    }

    private func sessionTotal(_ sets: [SetEntry]) -> String {
        if isDuration {
            return "\(sets.reduce(0) { $0 + $1.reps }) min"
        }
        let vol = sets.reduce(0.0) { $0 + Stats.setVolume($1) }
        return vol > 0 ? "\(Fmt.volumeK(vol)) \(Fmt.unitLabel)" : "\(sets.reduce(0) { $0 + $1.reps }) reps"
    }
}

// MARK: - Models

struct ExerciseSession {
    let workout: Workout
    let sets: [SetEntry]
}

struct SessionPoint: Identifiable {
    let date: Date
    let value: Double
    let isPR: Bool
    var id: Date { date }
}
