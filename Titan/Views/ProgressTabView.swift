import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    enum Period: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }

    @State private var period: Period = .week

    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }

    private var periodInterval: DateInterval {
        let now = Date()
        let cal = Calendar.current
        switch period {
        case .week:
            return Stats.weekInterval(containing: now)
        case .month:
            return cal.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
        case .year:
            return cal.dateInterval(of: .year, for: now) ?? DateInterval(start: now, duration: 0)
        }
    }

    private var muscleVolume: [Muscle: Double] {
        Stats.volumeByMuscle(Stats.workouts(finished, in: periodInterval))
    }

    private var maxVolume: Double {
        max(muscleVolume.values.max() ?? 1, 1)
    }

    private func intensity(_ m: Muscle) -> Double {
        (muscleVolume[m] ?? 0) / maxVolume
    }

    private var periodLabel: String {
        let f = DateFormatter()
        switch period {
        case .week:
            f.dateFormat = "MMM d"
            let fd = DateFormatter()
            fd.dateFormat = "d"
            let end = periodInterval.end.addingTimeInterval(-1)
            return "\(f.string(from: periodInterval.start))–\(fd.string(from: end))".uppercased()
        case .month:
            f.dateFormat = "MMMM"
            return f.string(from: Date()).uppercased()
        case .year:
            f.dateFormat = "yyyy"
            return f.string(from: Date())
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("PROGRESS")
                        .font(.condensed(36, weight: .heavy))
                        .kerning(2)
                        .foregroundStyle(Color.textMain)
                    Spacer()
                    periodPicker
                }
                .padding(.top, 6)

                heatMapCard

                muscleListCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .background(Color.bg.ignoresSafeArea())
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { p in
                let sel = period == p
                Button {
                    withAnimation(.snappy) { period = p }
                    Haptics.tap()
                } label: {
                    Text(p.rawValue)
                        .font(.barlow(11.5, weight: sel ? .semibold : .medium))
                        .foregroundStyle(sel ? .white : Color.textDim)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(sel ? Color.purplePrimary : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.surface))
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private var heatMapCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TRAINING VOLUME · \(periodLabel)")
                .font(.barlow(10.5, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Color.textDim)

            HStack(spacing: 34) {
                Spacer()
                VStack(spacing: 4) {
                    BodyHeatMap(front: true, intensity: intensity)
                    Text("FRONT")
                        .font(.barlow(9.5, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textFaint)
                }
                VStack(spacing: 4) {
                    BodyHeatMap(front: false, intensity: intensity)
                    Text("BACK")
                        .font(.barlow(9.5, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textFaint)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Text("LOW")
                    .font(.barlow(9, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(Color.textFaint)
                Capsule()
                    .fill(LinearGradient(colors: [.surface2, .purplePrimary, .glow], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 6)
                Text("HIGH")
                    .font(.barlow(9, weight: .semibold))
                    .kerning(1)
                    .foregroundStyle(Color.textFaint)
            }
            .padding(.top, 12)
        }
        .padding(16)
        .card(18)
    }

    private var muscleListCard: some View {
        let sorted = muscleVolume
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 11) {
            Text("VOLUME BY MUSCLE · LB")
                .font(.barlow(10.5, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Color.textDim)
                .padding(.bottom, 1)

            if sorted.isEmpty {
                Text("No training logged in this period")
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                ForEach(sorted, id: \.key) { muscle, vol in
                    HStack(spacing: 10) {
                        Text(muscle.rawValue)
                            .font(.barlow(12.5, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                            .frame(width: 82, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.surface2)
                                Capsule()
                                    .fill(LinearGradient(colors: [.purpleDeep, .purplePrimary, .purpleBright], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(9, geo.size.width * (vol / maxVolume)))
                            }
                        }
                        .frame(height: 9)
                        Text(Fmt.volumeK(vol))
                            .font(.condensed(16, weight: .bold))
                            .foregroundStyle(Color.textMain)
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .card(18)
    }
}
