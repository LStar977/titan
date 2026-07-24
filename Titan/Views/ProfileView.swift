import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [Profile]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query(sort: \BodyMetric.date, order: .reverse) private var metrics: [BodyMetric]

    @State private var showSettings = false
    @State private var showLogMetrics = false

    private var profile: Profile? { profiles.first }
    private var finished: [Workout] { workouts.filter { $0.endedAt != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    rankCard
                    climbCard
                    supplementsLink
                    bodyweightCard
                    measurementsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .sheet(isPresented: $showLogMetrics) {
            LogMetricsSheet()
        }
    }

    private var supplementsLink: some View {
        NavigationLink {
            SupplementsView()
        } label: {
            HStack {
                Image(systemName: "pills")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.purpleBright)
                Text("Supplements")
                    .font(.barlow(13.5, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textFaint)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .card(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: Header

    private var memberSince: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: profile?.createdAt ?? Date())
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text((profile?.name ?? "ATHLETE").uppercased())
                    .font(.condensed(32, weight: .heavy))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(finished.count) workout\(finished.count == 1 ? "" : "s") · since \(memberSince)")
                    .font(.barlow(11.5))
                    .foregroundStyle(Color.textDim)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textDim)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.surface2))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    // MARK: Rank

    private var rankCard: some View {
        let prog = RankSystem.progress(xp: profile?.xp ?? 0)
        return HStack(spacing: 16) {
            Hexagon()
                .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                .frame(width: 72, height: 80)
                .overlay(
                    Hexagon()
                        .fill(LinearGradient(colors: [.surface2, .surface], startPoint: .top, endPoint: .bottom))
                        .padding(3)
                )
                .overlay(
                    VStack(spacing: 3) {
                        LogoBars(barWidth: 4, barHeight: 15, color: .glow, glowRadius: 5)
                        Text(prog.rank.tierNumeral)
                            .font(.condensed(14, weight: .heavy))
                            .kerning(1)
                            .foregroundStyle(Color.glow)
                    }
                )

            VStack(alignment: .leading, spacing: 0) {
                Text("CURRENT RANK")
                    .font(.barlow(9.5, weight: .bold))
                    .kerning(2)
                    .foregroundStyle(Color.purpleBright)
                Text(prog.rank.title)
                    .font(.condensed(28, weight: .heavy))
                    .kerning(2)
                    .foregroundStyle(Color.textMain)
                    .shadow(color: Color.purplePrimary.opacity(0.5), radius: 9)
                RankProgressBar(fraction: prog.fraction)
                    .padding(.top, 7)
                Group {
                    if let next = prog.next {
                        Text("\(prog.current) / \(prog.span) XP · \(prog.span - prog.current) to \(next.title)")
                    } else {
                        Text("Highest rank achieved · \(profile?.xp ?? 0) XP")
                    }
                }
                .font(.barlow(10.5))
                .foregroundStyle(Color.textDim)
                .padding(.top, 5)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(LinearGradient(colors: [Color(hex: 0x17172A), .surface], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [Color.glow.opacity(0.6), Color.purplePrimary.opacity(0.15), Color.purpleDeep.opacity(0.4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.purplePrimary.opacity(0.18), radius: 13)
    }

    // MARK: The Climb

    private var climbCard: some View {
        let prog = RankSystem.progress(xp: profile?.xp ?? 0)
        let currentGroup = prog.rank.groupIndex
        return VStack(alignment: .leading, spacing: 12) {
            Text(Brand.climbTitle)
                .font(.barlow(10.5, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Color.textDim)

            HStack {
                ForEach(0..<4, id: \.self) { group in
                    Spacer()
                    climbEmblem(group: group, currentGroup: currentGroup, rank: prog.rank)
                    Spacer()
                }
            }
        }
        .padding(16)
        .card(16)
    }

    @ViewBuilder
    private func climbEmblem(group: Int, currentGroup: Int, rank: Rank) -> some View {
        let name = Rank.groupNames[group]
        VStack(spacing: 6) {
            if group < currentGroup {
                // Completed group
                Hexagon()
                    .fill(completedGradient(group))
                    .frame(width: 46, height: 51)
                    .overlay(
                        Text("III")
                            .font(.condensed(13, weight: .heavy))
                            .foregroundStyle(completedText(group))
                    )
                Text(name)
                    .font(.barlow(9.5, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Color.textDim)
            } else if group == currentGroup {
                Hexagon()
                    .fill(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 51)
                    .overlay(
                        Text(rank.tierNumeral)
                            .font(.condensed(13, weight: .heavy))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Color.purplePrimary.opacity(0.55), radius: 9)
                Text(name)
                    .font(.barlow(9.5, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Color.glow)
            } else {
                Hexagon()
                    .fill(Color(hex: 0x15151F))
                    .frame(width: 46, height: 51)
                    .overlay(
                        Image(systemName: "lock")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: 0x3A3A4E))
                    )
                Text(name)
                    .font(.barlow(9.5, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Color(hex: 0x3A3A4E))
            }
        }
    }

    private func completedGradient(_ group: Int) -> LinearGradient {
        if group == 0 {
            return LinearGradient(colors: [Color(hex: 0x3A2E22), Color(hex: 0x241D15)], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Color(hex: 0x3A3A4E), Color(hex: 0x23232E)], startPoint: .top, endPoint: .bottom)
    }

    private func completedText(_ group: Int) -> Color {
        group == 0 ? Color(hex: 0xC9A97E) : Color(hex: 0xB9B9C8)
    }

    // MARK: Bodyweight

    private var weightEntries: [BodyMetric] {
        metrics.filter { $0.weight != nil }
    }

    private var bodyweightCard: some View {
        let latest = weightEntries.first?.weight
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("BODYWEIGHT")
                    .font(.barlow(10.5, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textDim)
                Spacer()
                if let delta = monthDelta {
                    Text(delta >= 0 ? "↑ \(String(format: "%.1f", delta)) lb this month" : "↓ \(String(format: "%.1f", -delta)) lb this month")
                        .font(.barlow(11, weight: .semibold))
                        .foregroundStyle(Color.successGreen)
                }
            }
            HStack(alignment: .bottom, spacing: 14) {
                if let latest {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", latest))
                            .font(.condensed(38, weight: .bold))
                            .foregroundStyle(Color.textMain)
                        Text("lb")
                            .font(.condensed(18, weight: .bold))
                            .foregroundStyle(Color.textDim)
                    }
                } else {
                    Button {
                        showLogMetrics = true
                    } label: {
                        Text("Log your bodyweight")
                            .font(.barlow(13, weight: .semibold))
                            .foregroundStyle(Color.purpleBright)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                }
                Spacer()
                if weightEntries.count > 1 {
                    Sparkline(values: weightEntries.prefix(12).reversed().compactMap { $0.weight })
                }
            }
        }
        .padding(16)
        .card(16)
    }

    private var monthDelta: Double? {
        guard let latest = weightEntries.first?.weight else { return nil }
        let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        guard let past = weightEntries.last(where: { $0.date >= cutoff })?.weight, past != latest else { return nil }
        return latest - past
    }

    // MARK: Measurements

    private var measurementsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MEASUREMENTS")
                    .font(.barlow(10.5, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textDim)
                Spacer()
                Button {
                    showLogMetrics = true
                } label: {
                    Text("Log")
                        .font(.barlow(11.5, weight: .semibold))
                        .foregroundStyle(Color.purpleBright)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            .padding(.bottom, 9)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.hairline).frame(height: 1)
            }

            measurementRow("Chest", keyPath: \.chest)
            Divider().overlay(Color.white.opacity(0.04))
            measurementRow("Arm", keyPath: \.arm)
            Divider().overlay(Color.white.opacity(0.04))
            measurementRow("Waist", keyPath: \.waist)
        }
        .card(16)
    }

    private func measurementRow(_ label: String, keyPath: KeyPath<BodyMetric, Double?>) -> some View {
        let entries = metrics.compactMap { $0[keyPath: keyPath] }
        let latest = entries.first
        let previous = entries.count > 1 ? entries[1] : nil
        return HStack {
            Text(label)
                .font(.barlow(13.5, weight: .medium))
                .foregroundStyle(Color.textMain)
            Spacer()
            if let latest {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", latest))
                        .font(.condensed(18, weight: .bold))
                        .foregroundStyle(Color.textMain)
                    Text("in")
                        .font(.condensed(12, weight: .bold))
                        .foregroundStyle(Color.textDim)
                    if let previous, previous != latest {
                        let d = latest - previous
                        Text(d > 0 ? "+\(String(format: "%.1f", d))" : "−\(String(format: "%.1f", -d))")
                            .font(.barlow(11, weight: .semibold))
                            .foregroundStyle(Color.successGreen)
                    }
                }
            } else {
                Text("—")
                    .font(.condensed(18, weight: .bold))
                    .foregroundStyle(Color.textFaint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Settings

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [Profile]
    @State private var name = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Color.clear.frame(width: 50, height: 1)
                Spacer()
                Text("SETTINGS")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Done") {
                    if let p = profiles.first, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        p.name = name.trimmingCharacters(in: .whitespaces)
                    }
                    dismiss()
                }
                .font(.barlow(14, weight: .semibold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 50, alignment: .trailing)
            }
            .padding(.top, 18)

            if let profile = profiles.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR NAME")
                        .font(.barlow(9.5, weight: .bold))
                        .kerning(1.5)
                        .foregroundStyle(Color.textFaint)
                    TextField("Name", text: $name)
                        .font(.condensed(22, weight: .bold))
                        .foregroundStyle(Color.textMain)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 13).fill(Color.surface2))

                settingStepper("Weekly workout goal", value: "\(profile.weeklyGoal)") {
                    profile.weeklyGoal = max(1, profile.weeklyGoal - 1)
                } plus: {
                    profile.weeklyGoal = min(7, profile.weeklyGoal + 1)
                }

                settingStepper("Default rest timer", value: Fmt.clock(Double(profile.defaultRestSeconds))) {
                    profile.defaultRestSeconds = max(30, profile.defaultRestSeconds - 15)
                } plus: {
                    profile.defaultRestSeconds = min(600, profile.defaultRestSeconds + 15)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color(hex: 0x10101B).ignoresSafeArea())
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .onAppear { name = profiles.first?.name ?? "" }
    }

    private func settingStepper(_ label: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.barlow(11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(Color.textDim)
            Spacer()
            HStack(spacing: 14) {
                stepBtn("minus", action: minus)
                Text(value)
                    .font(.condensed(22, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .frame(minWidth: 52)
                    .monospacedDigit()
                stepBtn("plus", action: plus)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .card(13)
    }

    private func stepBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
        } label: {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.surface2)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.textSoft)
                )
        }
        .buttonStyle(.plain)
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

    private var hasInput: Bool {
        [weight, chest, arm, waist].contains { Double($0) != nil }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(14, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 60, alignment: .leading)
                Spacer()
                Text("LOG METRICS")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Save") {
                    let metric = BodyMetric(
                        weight: Double(weight),
                        chest: Double(chest),
                        arm: Double(arm),
                        waist: Double(waist)
                    )
                    context.insert(metric)
                    try? context.save()
                    Haptics.success()
                    dismiss()
                }
                .font(.barlow(14, weight: .bold))
                .foregroundStyle(hasInput ? Color.purpleBright : Color.textFaint)
                .disabled(!hasInput)
                .frame(width: 60, alignment: .trailing)
            }
            .padding(.top, 18)

            metricField("Bodyweight (lb)", text: $weight)
            metricField("Chest (in)", text: $chest)
            metricField("Arm (in)", text: $arm)
            metricField("Waist (in)", text: $waist)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color(hex: 0x10101B).ignoresSafeArea())
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }

    private func metricField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.barlow(9.5, weight: .bold))
                .kerning(1.5)
                .foregroundStyle(Color.textFaint)
            TextField("—", text: text)
                .font(.condensed(24, weight: .bold))
                .foregroundStyle(Color.textMain)
                .keyboardType(.decimalPad)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 13).fill(Color.surface2))
    }
}
