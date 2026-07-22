import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    let exerciseName: String

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var exercises: [Exercise]

    private var exercise: Exercise? {
        exercises.first { $0.name == exerciseName }
    }

    /// Newest-first sessions of this exercise with completed non-warm-up sets.
    private var sessions: [(workout: Workout, sets: [SetEntry])] {
        workouts.compactMap { w in
            guard w.endedAt != nil else { return nil }
            let sets = w.sortedEntries
                .filter { $0.displayName == exerciseName }
                .flatMap { $0.completedSets }
                .filter { $0.type != .warmup }
            return sets.isEmpty ? nil : (w, sets)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                BackHeader(label: "Back") { dismiss() }

                VStack(alignment: .leading, spacing: 1) {
                    Text(exerciseName.uppercased())
                        .font(.condensed(34, weight: .heavy))
                        .kerning(1)
                        .foregroundStyle(Color.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(subtitle)
                        .font(.barlow(10.5, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textDim)
                }

                statRow

                if e1rmSeries.count > 1 {
                    chartCard
                }

                if volumeSeries.contains(where: { $0 > 0 }) {
                    volumeCard
                }

                historyCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 130)
        }
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let ex = exercise {
            parts.append(ex.equipment.rawValue.uppercased())
            parts.append(ex.muscle.rawValue.uppercased())
        }
        parts.append("\(sessions.count) SESSION\(sessions.count == 1 ? "" : "S")")
        return parts.joined(separator: " · ")
    }

    // MARK: Stats

    private var bestE1RM: Double {
        sessions.flatMap { $0.sets }.map { Stats.e1RM($0.weight, $0.reps) }.max() ?? 0
    }

    private var lifetimeVolume: Double {
        sessions.flatMap { $0.sets }.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EST. 1RM")
                    .font(.barlow(9.5, weight: .semibold))
                    .kerning(1.5)
                    .foregroundStyle(Color.glow)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(bestE1RM))")
                        .font(.condensed(29, weight: .bold))
                        .foregroundStyle(Color.glow)
                        .shadow(color: Color.glow.opacity(0.5), radius: 6)
                    Text("lb")
                        .font(.condensed(15, weight: .bold))
                        .foregroundStyle(Color.textDim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .card(14, border: Color.glow.opacity(0.35))

            smallStat(
                label: "BEST SET",
                value: bestSetLabel
            )
            smallStat(
                label: "LIFETIME VOL",
                value: "\(Fmt.volumeK(lifetimeVolume)) lb"
            )
        }
    }

    private var bestSetLabel: String {
        if let best = Stats.bestSet(exerciseName: exerciseName, workouts: workouts) {
            return "\(Fmt.weight(best.weight))×\(best.reps)"
        }
        return "—"
    }

    private func smallStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.barlow(9.5, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(Color.textDim)
            Text(value)
                .font(.condensed(29, weight: .bold))
                .foregroundStyle(Color.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .card(14)
    }

    // MARK: Charts

    /// Session-max e1RM, oldest → newest, up to 12 sessions.
    private var e1rmSeries: [Double] {
        sessions
            .prefix(12)
            .reversed()
            .map { s in s.sets.map { Stats.e1RM($0.weight, $0.reps) }.max() ?? 0 }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ESTIMATED 1RM")
                    .font(.barlow(10.5, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textDim)
                Spacer()
                Text("LAST \(e1rmSeries.count) SESSIONS")
                    .font(.barlow(10.5, weight: .semibold))
                    .foregroundStyle(Color.textFaint)
            }
            LineChart(values: e1rmSeries)
            HStack {
                if let first = sessions.prefix(12).last {
                    Text(Fmt.shortDate(first.workout.startedAt).uppercased())
                        .font(.barlow(9.5, weight: .semibold))
                        .foregroundStyle(Color.textFaint)
                }
                Spacer()
                Text("\(Int(bestE1RM)) lb ✦")
                    .font(.barlow(10, weight: .bold))
                    .foregroundStyle(Color.glow)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .card(16)
    }

    /// Weekly volume over the last 8 calendar weeks.
    private var volumeSeries: [Double] {
        var out: [Double] = []
        let now = Date()
        for i in stride(from: 7, through: 0, by: -1) {
            guard let ref = Calendar.current.date(byAdding: .day, value: -7 * i, to: now) else { continue }
            let week = Stats.weekInterval(containing: ref)
            let vol = sessions
                .filter { week.contains($0.workout.startedAt) }
                .flatMap { $0.sets }
                .reduce(0.0) { $0 + $1.weight * Double($1.reps) }
            out.append(vol)
        }
        return out
    }

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEEKLY VOLUME · 8 WEEKS")
                .font(.barlow(10.5, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Color.textDim)
            BarChart(values: volumeSeries)
        }
        .padding(14)
        .card(16)
    }

    // MARK: History

    private var historyCard: some View {
        VStack(spacing: 0) {
            Text("HISTORY")
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

            if sessions.isEmpty {
                Text("No sessions logged yet")
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(sessions.enumerated()), id: \.offset) { i, session in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 7) {
                                Text("\(Fmt.shortDate(session.workout.startedAt)) · \(session.workout.title)")
                                    .font(.barlow(13.5, weight: .semibold))
                                    .foregroundStyle(Color.textMain)
                                if session.sets.contains(where: { $0.isPR }) {
                                    PRBadge(filled: true)
                                }
                            }
                            Text(session.sets.map { "\(Fmt.weight($0.weight))×\($0.reps)" }.joined(separator: " · "))
                                .font(.barlow(11.5))
                                .foregroundStyle(Color.textDim)
                                .lineLimit(1)
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(volumeString(session.sets))
                                .font(.condensed(18, weight: .bold))
                                .foregroundStyle(Color.textSoft)
                            Text("lb")
                                .font(.condensed(12, weight: .bold))
                                .foregroundStyle(Color.textFaint)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if i < sessions.count - 1 {
                        Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 16)
                    }
                }
            }
        }
        .card(16)
    }

    private func volumeString(_ sets: [SetEntry]) -> String {
        let vol = sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        let n = Int(vol)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
