import SwiftUI
import SwiftData
import StoreKit

/// The reward screen: what you did, what you broke, how far you climbed.
struct WorkoutCompleteView: View {
    let workout: Workout

    @Environment(AppState.self) private var app
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var profiles: [Profile]

    @State private var appeared = false
    @State private var xpShown = 0
    @State private var barFraction: Double = 0
    @State private var shareImage: Image?

    private var prs: [(name: String, set: SetEntry)] { Stats.prSets(workout) }

    private var summary: WorkoutSummary {
        if let s = app.summary { return s }
        let gained = RankSystem.xp(for: workout)
        let total = RankSystem.totalXP(workouts)
        return WorkoutSummary(xpGained: gained, xpBefore: total - gained, xpAfter: total)
    }

    /// The last time this same workout was done, for the comparison line.
    private var previous: Workout? {
        workouts.first { $0 !== workout && $0.endedAt != nil && $0.title == workout.title && $0.startedAt < workout.startedAt }
    }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Color.purplePrimary.opacity(0.28), .clear],
                center: .init(x: 0.5, y: 0.02),
                startRadius: 0, endRadius: 340
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    hero
                        .padding(.bottom, 4)

                    statsRow

                    if summary.rankedUp {
                        rankUpCard
                    }

                    if !prs.isEmpty {
                        recordsCard
                    }

                    if let comparison = comparisonText {
                        comparisonCard(comparison)
                    }

                    musclesCard

                    rankCard

                    actions
                        .padding(.top, 6)
                }
                .padding(.horizontal, Layout.screenPad)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
            }
        }
        .onAppear(perform: animateIn)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.purplePrimary.opacity(0.18))
                    .frame(width: 128, height: 128)
                    .blur(radius: 18)
                Hexagon()
                    .fill(LinearGradient(colors: [.surface3, .surface], startPoint: .top, endPoint: .bottom))
                    .frame(width: 92, height: 100)
                    .overlay(Hexagon().fill(Color.surface).padding(2.5))
                    .overlay(Hexagon().stroke(Color.purplePrimary.opacity(0.5), lineWidth: 1.5))
                    .overlay(LogoBars(barWidth: 7, barHeight: 26, color: .glow, glowRadius: 9))
                    .scaleEffect(appeared ? 1 : 0.6)
            }
            .frame(height: 118)

            Text(Brand.completeTitle)
                .font(.condensed(34, weight: .heavy))
                .kerning(3.5)
                .foregroundStyle(Color.textMain)
                .brandGlow(Color.purplePrimary.opacity(0.45), radius: 12)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subline = Brand.completeSubline {
                Text(subline.uppercased())
                    .font(.barlow(12, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(Color.purpleBright)
            }

            Text("\(workout.title) · \(Fmt.time(workout.endedAt ?? Date()))")
                .font(.barlow(15))
                .foregroundStyle(Color.textDim)
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            statTile(Fmt.duration(workout.duration), "TIME")
            statTile(Fmt.volumeK(Stats.volume(workout)), "\(Fmt.unitLabel.uppercased()) VOLUME")
            statTile("\(Stats.completedSetCount(workout))", "SETS")
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.condensed(26, weight: .bold))
                .foregroundStyle(Color.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.barlow(11, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.textFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card(16)
    }

    // MARK: Rank up

    private var rankUpCard: some View {
        HStack(spacing: 16) {
            RankEmblem(rank: summary.rankAfter, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(Brand.rankUpTitle)
                    .font(.barlow(12, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(Color.purpleBright)
                Text(summary.rankAfter.title)
                    .font(.condensed(30, weight: .heavy))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Text("Up from \(summary.rankBefore.title)")
                    .font(.barlow(14))
                    .foregroundStyle(Color.textDim)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color.purplePrimary.opacity(0.22), Color.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.glow.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: Color.purplePrimary.opacity(0.35), radius: 16)
    }

    // MARK: Records

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.glow)
                Text(prs.count == 1 ? "NEW RECORD" : "\(prs.count) NEW RECORDS")
                    .font(.barlow(12.5, weight: .bold))
                    .kerning(1.8)
                    .foregroundStyle(Color.glow)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ForEach(Array(prs.enumerated()), id: \.offset) { i, pr in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pr.name)
                            .font(.barlow(16, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                        Text(recordDetail(pr.set))
                            .font(.barlow(13))
                            .foregroundStyle(Color.textDim)
                    }
                    Spacer()
                    Text(pr.set.weight > 0 ? "\(Fmt.weight(pr.set.weight)) × \(pr.set.reps)" : "\(pr.set.reps) reps")
                        .font(.condensed(23, weight: .bold))
                        .foregroundStyle(Color.glow)
                        .brandGlow(Color.glow.opacity(0.5), radius: 6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                if i < prs.count - 1 {
                    Divider().overlay(Color.hairline).padding(.leading, 16)
                }
            }
        }
        .padding(.bottom, 4)
        .card(18, border: Color.glow.opacity(0.4))
    }

    private func recordDetail(_ set: SetEntry) -> String {
        if set.weight > 0 {
            return "New est. 1RM \(Fmt.whole(Stats.e1RM(set.weight, set.reps))) \(Fmt.unitLabel)"
        }
        return "Most reps ever"
    }

    // MARK: Comparison

    private var comparisonText: String? {
        guard let previous else { return nil }
        let now = Stats.volume(workout)
        let then = Stats.volume(previous)
        guard then > 0, now > 0 else { return nil }
        let pct = ((now - then) / then * 100).roundedInt
        if pct > 0 { return "Volume up \(pct)% on your last \(workout.title)." }
        if pct < 0 { return "Volume \(-pct)% under your last \(workout.title) — recovery days count too." }
        return "Matched your last \(workout.title) exactly."
    }

    private func comparisonCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.purplePrimary.opacity(0.12)))
            Text(text)
                .font(.barlow(15, weight: .medium))
                .foregroundStyle(Color.textSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .card(18)
    }

    // MARK: Muscles

    private var musclesCard: some View {
        let volume = Stats.volumeByMuscle([workout])
        let top = volume.max { $0.value < $1.value }?.value ?? 1
        let trained = volume
            .filter { !$0.key.isDuration && $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map { $0.key.rawValue }
        let female = profiles.first?.isFemale ?? Brand.defaultFemaleBody
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Muscles worked")
            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    BodyHeatMap(front: true, female: female, width: 64, height: 96) { m in
                        (volume[m] ?? 0) / max(top, 1)
                    }
                    BodyHeatMap(front: false, female: female, width: 64, height: 96) { m in
                        (volume[m] ?? 0) / max(top, 1)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if trained.isEmpty {
                        Text("Cardio and mobility today.")
                            .font(.barlow(14))
                            .foregroundStyle(Color.textDim)
                    } else {
                        ForEach(Array(trained.prefix(5).enumerated()), id: \.offset) { i, name in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.purplePrimary.opacity(i == 0 ? 1 : 0.55))
                                    .frame(width: 7, height: 7)
                                Text(name)
                                    .font(.barlow(15, weight: i == 0 ? .semibold : .regular))
                                    .foregroundStyle(i == 0 ? Color.textMain : Color.textSoft)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .card(18)
    }

    // MARK: Rank progress

    private var rankCard: some View {
        let after = RankSystem.progress(xp: summary.xpAfter)
        return HStack(spacing: 14) {
            RankEmblem(rank: after.rank, size: 46)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(after.rank.title)
                        .font(.condensed(19, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textMain)
                    Spacer()
                    Text("+\(xpShown) XP")
                        .font(.condensed(19, weight: .bold))
                        .foregroundStyle(Color.purpleBright)
                        .contentTransition(.numericText())
                }
                RankProgressBar(fraction: barFraction)
                    .padding(.top, 8)
                Group {
                    if let next = after.next {
                        Text("\(after.span - after.current) XP to \(next.title)")
                    } else {
                        Text("Highest rank achieved")
                    }
                }
                .font(.barlow(13))
                .foregroundStyle(Color.textDim)
                .padding(.top, 6)
            }
        }
        .padding(16)
        .card(18, border: Color.purplePrimary.opacity(0.35))
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 12) {
            GradientCTA("DONE", systemIcon: "checkmark") {
                done()
            }
            if let shareImage {
                ShareLink(
                    item: shareImage,
                    preview: SharePreview("\(workout.title) — \(Brand.plainName)", image: shareImage)
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Share workout card")
                            .font(.barlow(15.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.textMain)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.surface2))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.strokeStrong, lineWidth: 1))
                }
            }
        }
    }

    // MARK: Behaviour

    private func animateIn() {
        let before = RankSystem.progress(xp: summary.xpBefore)
        let after = RankSystem.progress(xp: summary.xpAfter)
        barFraction = summary.rankedUp ? 0 : before.fraction
        renderShareCard()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            appeared = true
        }
        withAnimation(.easeOut(duration: 1.1).delay(0.35)) {
            barFraction = after.fraction
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.9)) {
                xpShown = summary.xpGained
            }
        }
        if summary.rankedUp || !prs.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Haptics.pr()
            }
        }
    }

    private func renderShareCard() {
        let card = ShareCardView(
            title: workout.title,
            date: workout.startedAt,
            duration: Fmt.duration(workout.duration),
            volume: "\(Fmt.volumeK(Stats.volume(workout))) \(Fmt.unitLabel)",
            sets: Stats.completedSetCount(workout),
            records: prs.map { pr in
                (pr.name, pr.set.weight > 0 ? "\(Fmt.weight(pr.set.weight)) × \(pr.set.reps)" : "\(pr.set.reps) reps")
            },
            lifts: workout.sortedEntries.prefix(5).map { entry in
                (entry.displayName, liftSummary(entry))
            },
            rank: RankSystem.rank(xp: summary.xpAfter).title
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage {
            shareImage = Image(uiImage: ui)
        }
    }

    private func liftSummary(_ entry: WorkoutEntry) -> String {
        let n = entry.completedSets.count
        if entry.isDuration {
            return "\(entry.completedSets.reduce(0) { $0 + $1.reps }) min"
        }
        let setsText = "\(n) set\(n == 1 ? "" : "s")"
        let top = entry.workingSets.max { a, b in a.weight == b.weight ? a.reps < b.reps : a.weight < b.weight }
        if let top, top.weight > 0 {
            return "\(setsText) · \(Fmt.weight(top.weight)) × \(top.reps)"
        }
        return setsText
    }

    private func done() {
        if ReviewGate.recordFinished(hadPR: !prs.isEmpty) {
            requestReview()
        }
        app.endWorkoutFlow()
    }
}

// MARK: - Share card

/// A fixed-size card rendered to an image for Instagram stories and messages.
struct ShareCardView: View {
    let title: String
    let date: Date
    let duration: String
    let volume: String
    let sets: Int
    let records: [(String, String)]
    let lifts: [(String, String)]
    let rank: String

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    LogoBars(barWidth: 4, barHeight: 14, color: .white, glowRadius: 4)
                    Text(Brand.wordmark)
                        .font(.condensed(20, weight: .heavy))
                        .kerning(Brand.wordmarkKerning)
                }
                Spacer()
                Text(ShareCardView.dateFormatter.string(from: date).uppercased())
                    .font(.barlow(11, weight: .bold))
                    .kerning(1.5)
                    .opacity(0.75)
            }

            Text(title.uppercased())
                .font(.condensed(40, weight: .heavy))
                .kerning(1)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.top, 28)

            HStack(spacing: 16) {
                shareStat(duration, "TIME")
                shareStat(volume, "VOLUME")
                shareStat("\(sets)", "SETS")
            }
            .padding(.top, 12)

            if !records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                        Text(records.count == 1 ? "NEW RECORD" : "\(records.count) NEW RECORDS")
                            .font(.barlow(12, weight: .bold))
                            .kerning(1.6)
                    }
                    ForEach(Array(records.prefix(3).enumerated()), id: \.offset) { _, r in
                        HStack {
                            Text(r.0)
                                .font(.barlow(15, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text(r.1)
                                .font(.condensed(19, weight: .bold))
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.14)))
                .padding(.top, 20)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(lifts.enumerated()), id: \.offset) { _, lift in
                    HStack {
                        Text(lift.0)
                            .font(.barlow(14.5, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(lift.1)
                            .font(.barlow(14.5, weight: .semibold))
                            .opacity(0.85)
                    }
                }
            }
            .padding(.top, 20)

            Spacer(minLength: 16)

            HStack {
                Text(rank)
                    .font(.condensed(16, weight: .bold))
                    .kerning(1.5)
                Spacer()
                Text(Brand.shareFooter)
                    .font(.barlow(12, weight: .semibold))
                    .opacity(0.75)
            }
        }
        .foregroundStyle(.white)
        .padding(26)
        .frame(width: 360, height: 450)
        .background(
            ZStack {
                LinearGradient(
                    colors: Brand.shareGradient.map { Color(hex: $0) },
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.white.opacity(0.18), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: 260
                )
            }
        )
    }

    private func shareStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.condensed(22, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.barlow(10.5, weight: .bold))
                .kerning(1.4)
                .opacity(0.7)
        }
    }
}
