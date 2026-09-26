import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var profiles: [Profile]

    enum Period: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }

    enum HeatMetric: String, CaseIterable {
        case sets = "Sets"
        case volume = "Volume"
    }

    @State private var period: Period = .week
    @State private var metric: HeatMetric = .sets
    @State private var showBack = false

    private let cal = Calendar.current

    var body: some View {
        let done = workouts.filter { $0.endedAt != nil }
        let current = Stats.workouts(done, in: interval(for: period, offset: 0))
        let previous = Stats.workouts(done, in: interval(for: period, offset: -1))
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenTitle("PROGRESS")

                    PillPicker(options: Period.allCases, selection: $period) { $0.rawValue }

                    summaryCard(current, previous)
                    trendCard(done)
                    heatMapCard(current)
                    liftsSection(done)
                }
                .padding(.horizontal, Layout.screenPad)
                .padding(.bottom, Layout.tabBarClearance)
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Periods

    private func interval(for period: Period, offset: Int) -> DateInterval {
        let now = Date()
        switch period {
        case .week:
            let ref = cal.date(byAdding: .day, value: 7 * offset, to: now) ?? now
            return Stats.weekInterval(containing: ref)
        case .month:
            let ref = cal.date(byAdding: .month, value: offset, to: now) ?? now
            return cal.dateInterval(of: .month, for: ref) ?? DateInterval(start: ref, duration: 0)
        case .year:
            let ref = cal.date(byAdding: .year, value: offset, to: now) ?? now
            return cal.dateInterval(of: .year, for: ref) ?? DateInterval(start: ref, duration: 0)
        }
    }

    private var periodTitle: String {
        switch period {
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        }
    }

    private var previousName: String {
        switch period {
        case .week: return "last week"
        case .month: return "last month"
        case .year: return "last year"
        }
    }

    // MARK: Summary

    private func summaryCard(_ cur: [Workout], _ prev: [Workout]) -> some View {
        let curVol = cur.reduce(0.0) { $0 + Stats.volume($1) }
        let prevVol = prev.reduce(0.0) { $0 + Stats.volume($1) }
        let curSets = cur.reduce(0) { $0 + Stats.completedSetCount($1) }
        let prevSets = prev.reduce(0) { $0 + Stats.completedSetCount($1) }
        let curPRs = cur.reduce(0) { $0 + Stats.prSets($1).count }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(periodTitle)
                Spacer()
                Text("vs \(previousName)")
                    .font(.barlow(12.5))
                    .foregroundStyle(Color.textFaint)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                metricTile("\(cur.count)", "Workouts", change: countChange(cur.count, prev.count))
                metricTile(Fmt.volumeK(curVol), "\(Fmt.unitLabel) lifted", change: percentChange(curVol, prevVol))
                metricTile("\(curSets)", "Sets", change: percentChange(Double(curSets), Double(prevSets)))
                metricTile("\(curPRs)", Brand.recordsTile, change: nil, glow: curPRs > 0)
            }
        }
        .padding(16)
        .card(20)
    }

    private func metricTile(_ value: String, _ label: String, change: (text: String, up: Bool)?, glow: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.condensed(30, weight: .bold))
                .foregroundStyle(glow ? Color.glow : Color.textMain)
                .brandGlow(glow ? Color.glow.opacity(0.4) : .clear, radius: 6)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.barlow(11, weight: .semibold))
                    .kerning(1.1)
                    .foregroundStyle(Color.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let change {
                    Text(change.text)
                        .font(.barlow(11.5, weight: .bold))
                        .foregroundStyle(change.up ? Color.successGreen : Color.textFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.surface2.opacity(Brand.isLight ? 0.6 : 0.5)))
    }

    private func percentChange(_ now: Double, _ then: Double) -> (text: String, up: Bool)? {
        guard then > 0 else { return nil }
        let pct = ((now - then) / then * 100).roundedInt
        return pct >= 0 ? (text: "+\(pct)%", up: true) : (text: "−\(-pct)%", up: false)
    }

    private func countChange(_ now: Int, _ then: Int) -> (text: String, up: Bool)? {
        guard then > 0 || now > 0 else { return nil }
        let d = now - then
        if d == 0 { return (text: "=", up: true) }
        return d > 0 ? (text: "+\(d)", up: true) : (text: "−\(-d)", up: false)
    }

    // MARK: Trend

    private func trendCard(_ done: [Workout]) -> some View {
        let unit = Fmt.unit
        let weeks = Stats.weeklyVolumes(done, count: 12)
        let points = weeks.map { WeekPoint(start: $0.start, volume: unit.fromLb($0.volume)) }
        let currentStart = weeks.last?.start
        let hasData = points.contains { $0.volume > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Weekly volume")
                Spacer()
                Text("Last 12 weeks · \(unit.label)")
                    .font(.barlow(12.5))
                    .foregroundStyle(Color.textFaint)
            }
            if hasData {
                Chart(points) { point in
                    BarMark(
                        x: .value("Week", point.start, unit: .weekOfYear),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(point.start == currentStart ? Color.purpleBright : Color.purplePrimary.opacity(0.45))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.textFaint)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.hairline)
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>().notation(.compactName))
                            .foregroundStyle(Color.textFaint)
                    }
                }
                .frame(height: 160)
            } else {
                Text("Your weekly totals will build up here.")
                    .font(.barlow(14))
                    .foregroundStyle(Color.textDim)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding(16)
        .card(20)
    }

    // MARK: Heat map

    private func heatMapCard(_ current: [Workout]) -> some View {
        let values = metric == .sets ? Stats.setsByMuscle(current) : Stats.volumeByMuscle(current)
        let top = max(values.values.max() ?? 1, 1)
        let female = profiles.first?.isFemale ?? Brand.defaultFemaleBody
        let ranked = values
            .filter { $0.value > 0 && !$0.key.isDuration }
            .sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel("Muscles trained")
                Spacer()
                PillPicker(options: HeatMetric.allCases, selection: $metric) { $0.rawValue }
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 8) {
                    ZStack {
                        BodyHeatMap(front: !showBack, female: female, width: 128, height: 190) { m in
                            (values[m] ?? 0) / top
                        }
                        .id(showBack)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    }
                    Button {
                        withAnimation(.snappy) { showBack.toggle() }
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .bold))
                            Text(showBack ? "Front" : "Back")
                                .font(.barlow(13, weight: .semibold))
                        }
                        .foregroundStyle(Color.purpleBright)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.purplePrimary.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.purplePrimary.opacity(0.35), lineWidth: 1))
                        .frame(minHeight: Layout.minTap)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(showBack ? "Show front of body" : "Show back of body")
                }

                VStack(alignment: .leading, spacing: 10) {
                    if ranked.isEmpty {
                        Text("Nothing logged \(periodTitle.lowercased()) yet.")
                            .font(.barlow(14))
                            .foregroundStyle(Color.textDim)
                    } else {
                        ForEach(Array(ranked.prefix(7).enumerated()), id: \.offset) { _, item in
                            muscleRow(item.key, value: item.value, top: top)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                bodyTypeToggle(female: female)
                Spacer()
                HStack(spacing: 6) {
                    Text("Less")
                    Capsule()
                        .fill(LinearGradient(colors: [Color.purplePrimary.opacity(0.1), .purplePrimary, .glow], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 70, height: 6)
                    Text("More")
                }
                .font(.barlow(11.5, weight: .semibold))
                .foregroundStyle(Color.textFaint)
            }

            if metric == .sets && period == .week {
                Text("Most programs aim for roughly 10–20 hard sets per muscle each week.")
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
            }
        }
        .padding(16)
        .card(20)
    }

    private func muscleRow(_ muscle: Muscle, value: Double, top: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(muscle.rawValue)
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                Spacer()
                Text(metric == .sets ? "\(Fmt.num(value, decimals: 1)) sets" : "\(Fmt.volumeK(value))")
                    .font(.condensed(16, weight: .bold))
                    .foregroundStyle(Color.textSoft)
            }
            ThinProgressBar(fraction: value / top, height: 5)
        }
    }

    private func bodyTypeToggle(female: Bool) -> some View {
        HStack(spacing: 0) {
            bodyTypeButton("M", selected: !female) { setFemale(false) }
            bodyTypeButton("F", selected: female) { setFemale(true) }
        }
        .padding(2)
        .background(Capsule().fill(Color.surface2))
        .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Body figure")
    }

    private func bodyTypeButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.barlow(13, weight: .bold))
                .foregroundStyle(selected ? Color.white : Color.textDim)
                .frame(width: 34, height: 28)
                .background(Capsule().fill(selected ? Color.purplePrimary : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label == "M" ? "Male figure" : "Female figure")
    }

    private func setFemale(_ value: Bool) {
        withAnimation(.snappy) {
            profiles.first?.isFemale = value
        }
        Haptics.selection()
    }

    // MARK: Lifts

    private func liftsSection(_ done: [Workout]) -> some View {
        let lifts = keyLifts(done)
        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Your lifts")
            if lifts.isEmpty {
                EmptyStateCard(
                    systemIcon: "chart.line.uptrend.xyaxis",
                    title: "Trends need two sessions",
                    message: "Log a lift twice and its strength trend shows up here."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(lifts.enumerated()), id: \.offset) { i, lift in
                        NavigationLink {
                            ExerciseDetailView(exerciseName: lift.name)
                        } label: {
                            liftRow(lift)
                        }
                        .buttonStyle(.plain)
                        if i < lifts.count - 1 {
                            Divider().overlay(Color.hairline).padding(.leading, 16)
                        }
                    }
                }
                .card()
            }
        }
    }

    /// The most-trained lifts, each with its recent session-best e1RMs.
    private func keyLifts(_ done: [Workout]) -> [LiftTrend] {
        var byName: [String: [Double]] = [:]
        for w in done {
            for e in w.entries where !e.isDuration {
                let best = e.workingSets
                    .filter { $0.weight > 0 }
                    .map { Stats.e1RM($0.weight, $0.reps) }
                    .max() ?? 0
                guard best > 0 else { continue }
                byName[e.displayName, default: []].append(best)
            }
        }
        let ranked = byName
            .filter { $0.value.count >= 2 }
            .sorted { a, b in
                a.value.count == b.value.count ? a.key < b.key : a.value.count > b.value.count
            }
        return ranked.prefix(6).map { item in
            let recent = Array(item.value.prefix(10).reversed())
            return LiftTrend(
                name: item.key,
                points: recent,
                sessions: item.value.count,
                latest: recent.last ?? 0,
                change: (recent.last ?? 0) - (recent.first ?? 0)
            )
        }
    }

    private func liftRow(_ lift: LiftTrend) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(lift.name)
                    .font(.barlow(16, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Est. 1RM \(Fmt.whole(lift.latest)) \(Fmt.unitLabel) · \(lift.sessions) sessions")
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 6)
            Sparkline(values: lift.points, width: 60, height: 28)
            changeChip(lift.change)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textFaint)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 66)
        .contentShape(Rectangle())
    }

    private func changeChip(_ change: Double) -> some View {
        let shown = Fmt.unit.fromLb(abs(change)).roundedInt
        let up = change > 0.5
        let flat = shown == 0
        return Text(flat ? "±0" : (up ? "+\(shown)" : "−\(shown)"))
            .font(.condensed(15, weight: .bold))
            .foregroundStyle(up ? Color.successGreen : Color.textDim)
            .padding(.horizontal, 8)
            .frame(minWidth: 44, minHeight: 26)
            .background(
                Capsule().fill(up ? Color.successGreen.opacity(0.14) : Color.surface2)
            )
    }
}

// MARK: - Chart models

struct WeekPoint: Identifiable {
    let start: Date
    let volume: Double
    var id: Date { start }
}

struct LiftTrend {
    let name: String
    /// Session-best e1RMs, oldest → newest.
    let points: [Double]
    let sessions: Int
    let latest: Double
    let change: Double
}
