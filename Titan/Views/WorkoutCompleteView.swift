import SwiftUI
import SwiftData

struct WorkoutCompleteView: View {
    let workout: Workout
    @Environment(AppState.self) private var app
    @Query private var profiles: [Profile]

    private var prs: [(name: String, set: SetEntry)] { Stats.prSets(workout) }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Color.purplePrimary.opacity(0.2), .clear],
                center: .init(x: 0.5, y: 0.05),
                startRadius: 0, endRadius: 260
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Hexagon()
                        .fill(LinearGradient(colors: [.surface3, .surface], startPoint: .top, endPoint: .bottom))
                        .frame(width: 84, height: 92)
                        .overlay(Hexagon().fill(Color.surface).padding(2))
                        .overlay(LogoBars(barWidth: 6, barHeight: 22, color: .glow, glowRadius: 8))

                    Text("WORKOUT COMPLETE")
                        .font(.condensed(32, weight: .heavy))
                        .kerning(4)
                        .foregroundStyle(Color.textMain)
                        .shadow(color: Color.purplePrimary.opacity(0.4), radius: 12)
                        .padding(.top, 16)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    Text("\(workout.title) · \(finishedLabel)")
                        .font(.barlow(13))
                        .foregroundStyle(Color.textDim)
                        .padding(.top, 2)

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        summaryTile("DURATION", Fmt.clock(workout.duration), "")
                        summaryTile("VOLUME", Fmt.volumeK(Stats.volume(workout)), " lb")
                        summaryTile("SETS DONE", "\(Stats.completedSetCount(workout))", "")
                        summaryTile("PRS HIT", "\(prs.count)", "", glowing: prs.count > 0)
                    }
                    .padding(.top, 22)

                    // PR list
                    if !prs.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(prs.enumerated()), id: \.offset) { i, pr in
                                HStack(spacing: 12) {
                                    PRBadge(filled: true)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(pr.name)
                                            .font(.barlow(14, weight: .semibold))
                                            .foregroundStyle(Color.textMain)
                                        Text("new e1RM \(Int(Stats.e1RM(pr.set.weight, pr.set.reps))) lb")
                                            .font(.barlow(11.5))
                                            .foregroundStyle(Color.textDim)
                                    }
                                    Spacer()
                                    Text("\(Fmt.weight(pr.set.weight)) × \(pr.set.reps)")
                                        .font(.condensed(21, weight: .bold))
                                        .foregroundStyle(Color.glow)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                if i < prs.count - 1 {
                                    Divider().overlay(Color.hairline)
                                }
                            }
                        }
                        .card()
                        .padding(.top, 10)
                    }

                    // Rank progress
                    rankCard
                        .padding(.top, 10)

                    GradientCTA("DONE") {
                        app.endWorkoutFlow()
                    }
                    .padding(.top, 20)

                    ShareLink(item: shareText) {
                        HStack(spacing: 7) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Share summary")
                                .font(.barlow(13.5, weight: .semibold))
                        }
                        .foregroundStyle(Color.purpleBright)
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
    }

    private var finishedLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return "Today, \(f.string(from: workout.endedAt ?? Date()))"
    }

    private func summaryTile(_ label: String, _ value: String, _ unit: String, glowing: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.barlow(10, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(glowing ? Color.glow : Color.textDim)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.condensed(34, weight: .bold))
                    .foregroundStyle(glowing ? Color.glow : Color.textMain)
                    .shadow(color: glowing ? Color.glow.opacity(0.6) : .clear, radius: 8)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.condensed(18, weight: .bold))
                        .foregroundStyle(Color.textDim)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .card(16, border: glowing ? Color.glow.opacity(0.4) : .hairline)
        .shadow(color: glowing ? Color.purplePrimary.opacity(0.2) : .clear, radius: 10)
    }

    private var rankCard: some View {
        let xp = profiles.first?.xp ?? 0
        let prog = RankSystem.progress(xp: xp)
        return HStack(spacing: 12) {
            Hexagon()
                .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                .frame(width: 38, height: 42)
                .overlay(
                    Text(prog.rank.tierNumeral)
                        .font(.condensed(16, weight: .heavy))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(prog.rank.title)
                        .font(.condensed(17, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textMain)
                    Spacer()
                    Text("+\(app.xpGained) XP")
                        .font(.barlow(12, weight: .bold))
                        .foregroundStyle(Color.purpleBright)
                }
                RankProgressBar(fraction: prog.fraction)
                    .padding(.top, 7)
                Group {
                    if let next = prog.next {
                        Text("\(prog.current) / \(prog.span) XP · \(prog.span - prog.current) to ")
                            .foregroundStyle(Color.textDim)
                        + Text(next.title)
                            .font(.barlow(10.5, weight: .bold))
                            .foregroundStyle(Color.textSoft)
                    } else {
                        Text("Highest rank achieved")
                            .foregroundStyle(Color.textDim)
                    }
                }
                .font(.barlow(10.5))
                .padding(.top, 5)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 15).fill(Color.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.purplePrimary.opacity(0.6), Color.purplePrimary.opacity(0.1), Color.purpleDeep.opacity(0.3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var shareText: String {
        let vol = Fmt.volumeK(Stats.volume(workout))
        var text = "⚔️ TITAN — \(workout.title)\n\(Fmt.clock(workout.duration)) · \(vol) lb volume · \(Stats.completedSetCount(workout)) sets"
        if !prs.isEmpty {
            text += "\nPRs: " + prs.map { "\($0.name) \(Fmt.weight($0.set.weight))×\($0.set.reps)" }.joined(separator: ", ")
        }
        return text
    }
}

struct RankProgressBar: View {
    let fraction: Double
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.surface2)
                Capsule()
                    .fill(LinearGradient(colors: [.purpleDeep, .purplePrimary, .purpleBright], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * fraction))
                    .shadow(color: Color.purpleBright.opacity(0.6), radius: 5)
            }
        }
        .frame(height: height)
    }
}
