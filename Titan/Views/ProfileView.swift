import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [Profile]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query(sort: \BodyMetric.date, order: .reverse) private var metrics: [BodyMetric]

    @State private var showLogMetrics = false

    private var profile: Profile? { profiles.first }

    var body: some View {
        let done = workouts.filter { $0.endedAt != nil }
        let xp = RankSystem.totalXP(done)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header(done)
                    rankCard(xp: xp)
                    climbCard(xp: xp)
                    lifetimeCard(done)
                    bodyCard
                    linksCard
                }
                .padding(.horizontal, Layout.screenPad)
                .padding(.bottom, Layout.tabBarClearance)
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showLogMetrics) {
            LogMetricsSheet()
        }
    }

    // MARK: Header

    private func header(_ done: [Workout]) -> some View {
        let name = (profile?.name ?? "").trimmingCharacters(in: .whitespaces)
        let display = name.isEmpty ? "ATHLETE" : name.uppercased()
        return HStack(alignment: .center, spacing: 14) {
            ZStack {
                Hexagon()
                    .fill(Color.accentGradient)
                    .frame(width: 52, height: 57)
                Text(String(display.prefix(1)))
                    .font(.condensed(26, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.purplePrimary.opacity(0.4), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(display)
                    .font(.condensed(30, weight: .heavy))
                    .kerning(1.2)
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(done.count) workout\(done.count == 1 ? "" : "s") · since \(memberSince)")
                    .font(.barlow(14))
                    .foregroundStyle(Color.textDim)
            }
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.textSoft)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.surface2))
                    .frame(width: Layout.minTap, height: Layout.minTap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var memberSince: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: profile?.createdAt ?? Date())
    }

    // MARK: Rank

    private func rankCard(xp: Int) -> some View {
        let prog = RankSystem.progress(xp: xp)
        return HStack(spacing: 16) {
            RankEmblem(rank: prog.rank, size: 72)
            VStack(alignment: .leading, spacing: 0) {
                Text("CURRENT RANK")
                    .font(.barlow(11.5, weight: .bold))
                    .kerning(1.8)
                    .foregroundStyle(Color.purpleBright)
                Text(prog.rank.title)
                    .font(.condensed(30, weight: .heavy))
                    .kerning(1.8)
                    .foregroundStyle(Color.textMain)
                    .shadow(color: Color.purplePrimary.opacity(0.45), radius: 9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                RankProgressBar(fraction: prog.fraction)
                    .padding(.top, 8)
                Group {
                    if let next = prog.next {
                        Text("\(prog.current) / \(prog.span) XP · \(prog.span - prog.current) to \(next.title)")
                    } else {
                        Text("Highest rank achieved · \(xp) XP")
                    }
                }
                .font(.barlow(13))
                .foregroundStyle(Color.textDim)
                .padding(.top, 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Color.surfaceRaised, .surface], startPoint: .top, endPoint: .bottom))
                .shadow(color: Brand.isLight ? Color.black.opacity(0.06) : .clear, radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.glow.opacity(0.6), Color.purplePrimary.opacity(0.15), Color.purpleDeep.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.purplePrimary.opacity(0.16), radius: 13)
    }

    // MARK: The Climb

    private func climbCard(xp: Int) -> some View {
        let prog = RankSystem.progress(xp: xp)
        let currentGroup = prog.rank.groupIndex
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(Brand.climbTitle)
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { group in
                    climbEmblem(group: group, currentGroup: currentGroup, rank: prog.rank)
                        .frame(maxWidth: .infinity)
                }
            }
            Text("XP comes from every workout, every working set, and every record.")
                .font(.barlow(13))
                .foregroundStyle(Color.textDim)
        }
        .padding(16)
        .card(20)
    }

    @ViewBuilder
    private func climbEmblem(group: Int, currentGroup: Int, rank: Rank) -> some View {
        let name = Rank.groupNames[group]
        VStack(spacing: 7) {
            if group < currentGroup {
                Hexagon()
                    .fill(completedGradient(group))
                    .frame(width: 48, height: 53)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(completedText(group))
                    )
                Text(name)
                    .font(.barlow(11, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(Color.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if group == currentGroup {
                Hexagon()
                    .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 53)
                    .overlay(
                        Text(rank.tierNumeral)
                            .font(.condensed(16, weight: .heavy))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Color.purplePrimary.opacity(0.55), radius: 9)
                Text(name)
                    .font(.barlow(11, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(Color.glow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Hexagon()
                    .fill(Color.surfaceSunken)
                    .frame(width: 48, height: 53)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.outline)
                    )
                Text(name)
                    .font(.barlow(11, weight: .bold))
                    .kerning(0.8)
                    .foregroundStyle(Color.textFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func completedGradient(_ group: Int) -> LinearGradient {
        let hexes = group == 0 ? Brand.rankLowGradient : Brand.rankMidGradient
        return LinearGradient(colors: hexes.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
    }

    private func completedText(_ group: Int) -> Color {
        Color(hex: group == 0 ? Brand.rankLowText : Brand.rankMidText)
    }

    // MARK: Lifetime

    private func lifetimeCard(_ done: [Workout]) -> some View {
        let volume = done.reduce(0.0) { $0 + Stats.volume($1) }
        let sets = done.reduce(0) { $0 + Stats.completedSetCount($1) }
        let time = done.reduce(0.0) { $0 + $1.duration }
        let prs = done.reduce(0) { $0 + Stats.prSets($1).count }
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Lifetime")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Fmt.volumeK(volume))
                    .font(.condensed(40, weight: .bold))
                    .foregroundStyle(Color.textMain)
                Text("\(Fmt.unitLabel) lifted")
                    .font(.condensed(18, weight: .bold))
                    .foregroundStyle(Color.textDim)
                Spacer()
                if let comparison = volumeComparison(volume) {
                    Text(comparison)
                        .font(.barlow(13, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            HStack(spacing: 0) {
                lifetimeStat("\(done.count)", "WORKOUTS")
                lifetimeStat("\(sets)", "SETS")
                lifetimeStat(Fmt.hours(time), "TRAINING")
                lifetimeStat("\(prs)", Brand.recordsTile.uppercased(), glow: prs > 0)
            }
        }
        .padding(16)
        .card(20)
    }

    private func lifetimeStat(_ value: String, _ label: String, glow: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A physical comparison for lifetime volume — mass is mass in any unit.
    private func volumeComparison(_ lb: Double) -> String? {
        let things: [(name: String, lb: Double)] = [
            ("blue whales", 300_000),
            ("elephants", 13_000),
            ("pickup trucks", 5_000),
            ("grand pianos", 1_000)
        ]
        for thing in things where lb >= thing.lb * 2 {
            let n = lb / thing.lb
            return "≈ \(Fmt.num(n, decimals: n < 10 ? 1 : 0)) \(thing.name)"
        }
        return nil
    }

    // MARK: Body

    private var weightEntries: [BodyMetric] {
        metrics.filter { $0.weight != nil }
    }

    private var bodyCard: some View {
        let latest = weightEntries.first?.weight
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel("Body")
                Spacer()
                Button {
                    showLogMetrics = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Log")
                            .font(.barlow(14, weight: .semibold))
                    }
                    .foregroundStyle(Color.purpleBright)
                    .frame(minHeight: Layout.minTap)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            HStack(alignment: .bottom, spacing: 14) {
                if let latest {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(Fmt.num(Fmt.unit.fromLb(latest), decimals: 1))
                                .font(.condensed(38, weight: .bold))
                                .foregroundStyle(Color.textMain)
                            Text(Fmt.unitLabel)
                                .font(.condensed(18, weight: .bold))
                                .foregroundStyle(Color.textDim)
                        }
                        if let delta = monthDelta {
                            Text(deltaText(delta))
                                .font(.barlow(13, weight: .semibold))
                                .foregroundStyle(Color.textSoft)
                        } else {
                            Text("Bodyweight")
                                .font(.barlow(13))
                                .foregroundStyle(Color.textDim)
                        }
                    }
                } else {
                    Button {
                        showLogMetrics = true
                    } label: {
                        Text("Log your bodyweight — push-ups and pull-ups use it for volume.")
                            .font(.barlow(14, weight: .medium))
                            .foregroundStyle(Color.textDim)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if weightEntries.count > 1 {
                    Sparkline(values: weightEntries.prefix(12).reversed().compactMap { $0.weight }, width: 120, height: 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Rectangle().fill(Color.hairline).frame(height: 1)

            measurementRow("Chest", keyPath: \.chest)
            Divider().overlay(Color.hairlineSoft).padding(.leading, 16)
            measurementRow("Arm", keyPath: \.arm)
            Divider().overlay(Color.hairlineSoft).padding(.leading, 16)
            measurementRow("Waist", keyPath: \.waist)
        }
        .card(20)
    }

    private var monthDelta: Double? {
        guard let latest = weightEntries.first?.weight else { return nil }
        let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        guard let past = weightEntries.last(where: { $0.date >= cutoff })?.weight, past != latest else { return nil }
        return latest - past
    }

    private func deltaText(_ lbDelta: Double) -> String {
        let shown = Fmt.num(Fmt.unit.fromLb(abs(lbDelta)), decimals: 1)
        return lbDelta >= 0 ? "↑ \(shown) \(Fmt.unitLabel) this month" : "↓ \(shown) \(Fmt.unitLabel) this month"
    }

    private func measurementRow(_ label: String, keyPath: KeyPath<BodyMetric, Double?>) -> some View {
        let entries = metrics.compactMap { $0[keyPath: keyPath] }
        let latest = entries.first
        let previous = entries.count > 1 ? entries[1] : nil
        return HStack {
            Text(label)
                .font(.barlow(15.5, weight: .medium))
                .foregroundStyle(Color.textMain)
            Spacer()
            if let latest {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Fmt.length(latest))
                        .font(.condensed(20, weight: .bold))
                        .foregroundStyle(Color.textMain)
                    Text(Fmt.unit.lengthLabel)
                        .font(.condensed(13, weight: .bold))
                        .foregroundStyle(Color.textDim)
                    if let previous, previous != latest {
                        let d = Fmt.unit.fromInches(latest - previous)
                        Text(d > 0 ? "+\(Fmt.num(d, decimals: 1))" : "−\(Fmt.num(-d, decimals: 1))")
                            .font(.barlow(12.5, weight: .semibold))
                            .foregroundStyle(Color.textSoft)
                            .padding(.leading, 4)
                    }
                }
            } else {
                Text("—")
                    .font(.condensed(20, weight: .bold))
                    .foregroundStyle(Color.textFaint)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
    }

    // MARK: Links

    private var linksCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SupplementsView()
            } label: {
                linkRow(icon: "pills.fill", title: "Supplements")
            }
            .buttonStyle(.plain)
            Divider().overlay(Color.hairlineSoft).padding(.leading, 56)
            NavigationLink {
                RoutinesView()
            } label: {
                linkRow(icon: "list.bullet.rectangle", title: "Routines & programs")
            }
            .buttonStyle(.plain)
            Divider().overlay(Color.hairlineSoft).padding(.leading, 56)
            NavigationLink {
                SettingsView()
            } label: {
                linkRow(icon: "gearshape.fill", title: "Settings")
            }
            .buttonStyle(.plain)
        }
        .card(20)
    }

    private func linkRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 26)
            Text(title)
                .font(.barlow(16, weight: .semibold))
                .foregroundStyle(Color.textMain)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textFaint)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

// MARK: - Log metrics

struct LogMetricsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var weight = ""
    @State private var chest = ""
    @State private var arm = ""
    @State private var waist = ""

    private func parse(_ s: String) -> Double? {
        NumberField.parse(s)
    }

    private var hasInput: Bool {
        [weight, chest, arm, waist].contains { (parse($0) ?? 0) > 0 }
    }

    var body: some View {
        let unit = Fmt.unit
        return VStack(spacing: 14) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(16, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 70, alignment: .leading)
                Spacer()
                Text("LOG BODY")
                    .font(.condensed(20, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Save") {
                    let metric = BodyMetric(
                        weight: parse(weight).map { unit.toLb($0) },
                        chest: parse(chest).map { unit.toInches($0) },
                        arm: parse(arm).map { unit.toInches($0) },
                        waist: parse(waist).map { unit.toInches($0) }
                    )
                    context.insert(metric)
                    try? context.save()
                    Haptics.success()
                    dismiss()
                }
                .font(.barlow(16, weight: .bold))
                .foregroundStyle(hasInput ? Color.purpleBright : Color.textFaint)
                .disabled(!hasInput)
                .frame(width: 70, alignment: .trailing)
            }
            .padding(.top, 18)

            metricField("Bodyweight (\(unit.label))", text: $weight)
            metricField("Chest (\(unit.lengthLabel))", text: $chest)
            metricField("Arm (\(unit.lengthLabel))", text: $arm)
            metricField("Waist (\(unit.lengthLabel))", text: $waist)

            Text("Fill in any you like — blanks are skipped.")
                .font(.barlow(13))
                .foregroundStyle(Color.textDim)

            Spacer()
        }
        .padding(.horizontal, Layout.screenPad)
        .background(Color.sheetBg.ignoresSafeArea())
        .presentationDetents([.height(470), .large])
        .presentationDragIndicator(.visible)
    }

    private func metricField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.barlow(11, weight: .bold))
                .kerning(1.4)
                .foregroundStyle(Color.textFaint)
            TextField("—", text: text)
                .font(.condensed(26, weight: .bold))
                .foregroundStyle(Color.textMain)
                .keyboardType(.decimalPad)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.surface2))
    }
}
