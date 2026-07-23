import SwiftUI
import SwiftData

struct SupplementsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Supplement.orderIndex) private var supplements: [Supplement]
    @Query(sort: \SupplementLog.date, order: .reverse) private var logs: [SupplementLog]

    @State private var showAdd = false

    private let cal = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                BackHeader(label: "Back", trailing: AnyView(addButton)) { dismiss() }

                Text("SUPPLEMENTS")
                    .font(.condensed(36, weight: .heavy))
                    .kerning(2)
                    .foregroundStyle(Color.textMain)

                SectionLabel("Today · \(todayLabel)")
                    .padding(.top, 4)

                if supplements.isEmpty {
                    Text("No supplements yet — add one to start tracking.")
                        .font(.barlow(13))
                        .foregroundStyle(Color.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .card()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(supplements.enumerated()), id: \.offset) { i, supplement in
                            supplementRow(supplement)
                            if i < supplements.count - 1 {
                                Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 16)
                            }
                        }
                    }
                    .card()
                }

                Button {
                    showAdd = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add Supplement")
                            .font(.barlow(13, weight: .semibold))
                    }
                    .foregroundStyle(Color.purpleBright)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.purplePrimary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                }
                .buttonStyle(.plain)

                SectionLabel("Last 7 days")
                    .padding(.top, 12)

                weekHistory
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
        }
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) {
            AddSupplementSheet()
        }
    }

    private var addButton: some View {
        Button {
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.surface2))
        }
        .buttonStyle(.plain)
    }

    private var todayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: Date())
    }

    // MARK: Rows

    private func todayLogs(for supplement: Supplement) -> [SupplementLog] {
        logs.filter { $0.name == supplement.name && cal.isDateInToday($0.date) }
    }

    private func supplementRow(_ supplement: Supplement) -> some View {
        let today = todayLogs(for: supplement)
        let total = today.reduce(0.0) { $0 + $1.amount }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(supplement.name)
                    .font(.barlow(14.5, weight: .semibold))
                    .foregroundStyle(Color.textMain)
                Text("\(Fmt.weight(supplement.serving)) \(supplement.unit) per serving")
                    .font(.barlow(11.5))
                    .foregroundStyle(Color.textDim)
            }
            Spacer()
            if total > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(Fmt.weight(total))
                        .font(.condensed(24, weight: .bold))
                        .foregroundStyle(Color.purpleBright)
                    Text(supplement.unit)
                        .font(.condensed(14, weight: .bold))
                        .foregroundStyle(Color.textDim)
                }
            } else {
                Text("—")
                    .font(.condensed(24, weight: .bold))
                    .foregroundStyle(Color.textFaint)
            }
            HStack(spacing: 6) {
                roundButton("minus", disabled: today.isEmpty) {
                    if let latest = today.first {
                        context.delete(latest)
                        try? context.save()
                        Haptics.tap()
                    }
                }
                roundButton("plus", disabled: false) {
                    context.insert(SupplementLog(supplement: supplement))
                    try? context.save()
                    Haptics.medium()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button(role: .destructive) {
                context.delete(supplement)
                try? context.save()
            } label: {
                Label("Delete Supplement", systemImage: "trash")
            }
        }
    }

    private func roundButton(_ icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 10)
                .fill(icon == "plus" ? AnyShapeStyle(LinearGradient(colors: [.purplePrimary, .purpleDeep], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.surface2))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(icon == "plus" ? .white : Color.textSoft)
                )
                .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: Week history

    private var weekHistory: some View {
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
                dayRow(day)
                if offset < 6 {
                    Divider().overlay(Color.white.opacity(0.04)).padding(.leading, 16)
                }
            }
        }
        .card()
    }

    private func dayRow(_ day: Date) -> some View {
        let dayLogs = logs.filter { cal.isDate($0.date, inSameDayAs: day) }
        var totals: [String: (amount: Double, unit: String)] = [:]
        for log in dayLogs {
            let cur = totals[log.name]?.amount ?? 0
            totals[log.name] = (cur + log.amount, log.unit)
        }
        let summary = totals
            .sorted { $0.key < $1.key }
            .map { "\($0.key) \(Fmt.weight($0.value.amount)) \($0.value.unit)" }
            .joined(separator: " · ")

        let f = DateFormatter()
        f.dateFormat = "EEE"
        let label = cal.isDateInToday(day) ? "Today" : f.string(from: day)

        return HStack {
            Text(label)
                .font(.barlow(12.5, weight: .semibold))
                .foregroundStyle(cal.isDateInToday(day) ? Color.purpleBright : Color.textMain)
                .frame(width: 56, alignment: .leading)
            if summary.isEmpty {
                Text("Nothing logged")
                    .font(.barlow(12))
                    .foregroundStyle(Color.textFaint)
            } else {
                Text(summary)
                    .font(.barlow(12))
                    .foregroundStyle(Color.textDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

// MARK: - Add supplement

struct AddSupplementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Supplement.orderIndex) private var supplements: [Supplement]

    @State private var name = ""
    @State private var serving = ""
    @State private var unit = "g"

    private let units = ["g", "mg", "scoop", "pill", "ml"]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(serving) ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.barlow(14, weight: .medium))
                    .foregroundStyle(Color.purpleBright)
                    .frame(width: 60, alignment: .leading)
                Spacer()
                Text("NEW SUPPLEMENT")
                    .font(.condensed(19, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textMain)
                Spacer()
                Button("Save") {
                    let s = Supplement(
                        name: name.trimmingCharacters(in: .whitespaces),
                        serving: Double(serving) ?? 1,
                        unit: unit,
                        orderIndex: (supplements.map { $0.orderIndex }.max() ?? -1) + 1
                    )
                    context.insert(s)
                    try? context.save()
                    Haptics.success()
                    dismiss()
                }
                .font(.barlow(14, weight: .bold))
                .foregroundStyle(canSave ? Color.purpleBright : Color.textFaint)
                .disabled(!canSave)
                .frame(width: 60, alignment: .trailing)
            }
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 4) {
                Text("NAME")
                    .font(.barlow(9.5, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textFaint)
                TextField("e.g. Creatine", text: $name)
                    .font(.condensed(22, weight: .bold))
                    .foregroundStyle(Color.textMain)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 13).fill(Color.surface2))

            VStack(alignment: .leading, spacing: 4) {
                Text("SERVING SIZE")
                    .font(.barlow(9.5, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.textFaint)
                TextField("5", text: $serving)
                    .font(.condensed(22, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .keyboardType(.decimalPad)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 13).fill(Color.surface2))

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Unit")
                HStack(spacing: 6) {
                    ForEach(units, id: \.self) { u in
                        let sel = unit == u
                        Button {
                            unit = u
                            Haptics.tap()
                        } label: {
                            Text(u)
                                .font(.barlow(13, weight: .semibold))
                                .foregroundStyle(sel ? .white : Color.textDim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule().fill(sel ? AnyShapeStyle(Color.purplePrimary) : AnyShapeStyle(Color.surface2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 20)
        .background(Color(hex: 0x10101B).ignoresSafeArea())
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}
