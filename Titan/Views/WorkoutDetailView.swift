import SwiftUI
import SwiftData

/// Full breakdown of a finished workout: every exercise, every set, big type.
/// Pushed from History, or presented as a sheet from exercise history rows.
struct WorkoutDetailView: View {
    let workout: Workout
    var asSheet = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if asSheet {
                    HStack {
                        Color.clear.frame(width: 50, height: 1)
                        Spacer()
                        Text("WORKOUT")
                            .font(.condensed(19, weight: .bold))
                            .kerning(1.5)
                            .foregroundStyle(Color.textMain)
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(.barlow(14, weight: .semibold))
                            .foregroundStyle(Color.purpleBright)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.top, 16)
                } else {
                    BackHeader(label: "History") { dismiss() }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(dateLabel)
                        .font(.barlow(10, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(Color.purpleBright)
                    Text(workout.title.uppercased())
                        .font(.condensed(34, weight: .heavy))
                        .kerning(1)
                        .foregroundStyle(Color.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                HStack(spacing: 10) {
                    statTile(Fmt.clock(workout.duration), "TIME")
                    statTile(Fmt.volumeK(Stats.volume(workout)), "LB VOL")
                    statTile("\(Stats.completedSetCount(workout))", "SETS")
                    statTile("\(Stats.prSets(workout).count)", "PRS", glow: !Stats.prSets(workout).isEmpty)
                }

                ForEach(workout.sortedEntries) { entry in
                    entryCard(entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, asSheet ? 40 : 130)
        }
        .background((asSheet ? Color.sheetBg : Color.bg).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: workout.startedAt).uppercased()
    }

    private func statTile(_ value: String, _ label: String, glow: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.condensed(22, weight: .bold))
                .foregroundStyle(glow ? Color.glow : Color.textMain)
                .shadow(color: glow ? Color.glow.opacity(0.5) : .clear, radius: 6)
            Text(label)
                .font(.barlow(9, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Color.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .card(13)
    }

    private func entryCard(_ entry: WorkoutEntry) -> some View {
        let done = entry.completedSets
        let isDuration = entry.exercise?.muscle.isDuration ?? false
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayName)
                    .font(.condensed(21, weight: .bold))
                    .foregroundStyle(Color.textMain)
                if let ex = entry.exercise {
                    Text("\(ex.equipment.rawValue.uppercased()) · \(ex.muscle.rawValue.uppercased())")
                        .font(.barlow(10, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textDim)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }

            if done.isEmpty {
                Text("No sets completed")
                    .font(.barlow(12.5))
                    .foregroundStyle(Color.textFaint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(done.enumerated()), id: \.offset) { i, set in
                    HStack(spacing: 12) {
                        setBadge(set, in: entry)
                        if isDuration {
                            Text("\(set.reps)")
                                .font(.condensed(21, weight: .bold))
                                .foregroundStyle(Color.textMain)
                            + Text(" min")
                                .font(.condensed(14, weight: .bold))
                                .foregroundStyle(Color.textDim)
                        } else {
                            Text(loadLabel(set))
                                .font(.condensed(21, weight: .bold))
                                .foregroundStyle(set.isPR ? Color.glow : Color.textMain)
                                .shadow(color: set.isPR ? Color.glow.opacity(0.5) : .clear, radius: 6)
                        }
                        if set.isPR {
                            PRBadge(filled: true)
                        }
                        Spacer()
                        if !isDuration, Stats.setVolume(set) > 0 {
                            Text("\(Int(Stats.setVolume(set))) lb")
                                .font(.barlow(11.5))
                                .foregroundStyle(Color.textFaint)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    if i < done.count - 1 {
                        Divider().overlay(Color.hairlineSoft).padding(.leading, 16)
                    }
                }
            }
        }
        .card(16)
    }

    private func loadLabel(_ set: SetEntry) -> String {
        if set.weight > 0 {
            return "\(Fmt.weight(set.weight)) lb × \(set.reps)"
        }
        if set.bodyLoad > 0 {
            return "BW × \(set.reps)"
        }
        return "— × \(set.reps)"
    }

    private func setBadge(_ set: SetEntry, in entry: WorkoutEntry) -> some View {
        let label: String
        switch set.type {
        case .warmup: label = "W"
        case .failure: label = "F"
        case .drop: label = "D"
        case .working:
            var n = 0
            for s in entry.sortedSets {
                if s.type != .warmup { n += 1 }
                if s === set { break }
            }
            label = "\(n)"
        }
        return Text(label)
            .font(.condensed(13, weight: .bold))
            .foregroundStyle(set.type == .failure ? Color.dangerRed : Color.textSoft)
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.surface2))
    }
}
