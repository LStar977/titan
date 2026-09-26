import SwiftUI
import SwiftData
import StoreKit
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Query private var profiles: [Profile]
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    @State private var name = ""
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var csv: String?

    private var profile: Profile? { profiles.first }

    var body: some View {
        let prefs = Prefs.shared
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BackHeader(label: "Profile") {
                    saveName()
                    dismiss()
                }
                ScreenTitle("SETTINGS")

                section("You") {
                    row {
                        Text("Name")
                            .font(.barlow(16, weight: .medium))
                            .foregroundStyle(Color.textMain)
                        Spacer()
                        TextField("Your name", text: $name)
                            .font(.barlow(16, weight: .semibold))
                            .foregroundStyle(Color.textMain)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .onSubmit(saveName)
                    }
                }

                section("Units") {
                    row {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weight")
                                .font(.barlow(16, weight: .medium))
                                .foregroundStyle(Color.textMain)
                            Text("Your history converts automatically.")
                                .font(.barlow(12.5))
                                .foregroundStyle(Color.textDim)
                        }
                        Spacer()
                        PillPicker(
                            options: WeightUnit.allCases,
                            selection: Binding(get: { prefs.unit }, set: { prefs.setUnit($0) })
                        ) { $0.label }
                    }
                }

                section("Training") {
                    if let profile {
                        stepperRow(
                            title: "Weekly goal",
                            value: "\(profile.weeklyGoal) workouts",
                            minus: { profile.weeklyGoal = max(1, profile.weeklyGoal - 1) },
                            plus: { profile.weeklyGoal = min(7, profile.weeklyGoal + 1) }
                        )
                        divider
                        stepperRow(
                            title: "Default rest",
                            value: Fmt.clock(Double(profile.defaultRestSeconds)),
                            minus: { profile.defaultRestSeconds = max(30, profile.defaultRestSeconds - 15) },
                            plus: { profile.defaultRestSeconds = min(600, profile.defaultRestSeconds + 15) }
                        )
                        divider
                    }
                    toggleRow(
                        title: "Rest alerts",
                        detail: restAlertDetail,
                        isOn: Binding(get: { prefs.restAlerts }, set: { setRestAlerts($0) })
                    )
                    if notificationStatus == .denied && prefs.restAlerts {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text("Notifications are off for \(Brand.plainName). Turn them on in Settings.")
                                    .font(.barlow(13, weight: .semibold))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(Color.purpleBright)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    divider
                    toggleRow(
                        title: "Suggest weight increases",
                        detail: "When you hit the top of a routine's rep range on every set, the next session starts one step heavier.",
                        isOn: Binding(get: { prefs.autoProgress }, set: { prefs.setAutoProgress($0) })
                    )
                }

                section("Heat map") {
                    row {
                        Text("Body figure")
                            .font(.barlow(16, weight: .medium))
                            .foregroundStyle(Color.textMain)
                        Spacer()
                        PillPicker(
                            options: [false, true],
                            selection: Binding(
                                get: { profile?.isFemale ?? Brand.defaultFemaleBody },
                                set: { profile?.isFemale = $0 }
                            )
                        ) { $0 ? "Female" : "Male" }
                    }
                }

                section("Your data") {
                    if let csv, !workouts.isEmpty {
                        ShareLink(
                            item: CSVFile(text: csv),
                            preview: SharePreview("\(Brand.plainName) workouts.csv", image: Image(systemName: "tablecells"))
                        ) {
                            linkLabel(icon: "square.and.arrow.up", title: "Export workouts (CSV)", detail: "Every set, ready for a spreadsheet.")
                        }
                        .buttonStyle(.plain)
                        divider
                    }
                    row {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.purpleBright)
                            .frame(width: 24)
                        Text("Everything stays on this iPhone. No account, no tracking, nothing uploaded.")
                            .font(.barlow(14))
                            .foregroundStyle(Color.textDim)
                    }
                }

                section("About") {
                    Link(destination: Links.support) {
                        linkLabel(icon: "questionmark.circle.fill", title: "Help & support", detail: nil)
                    }
                    .buttonStyle(.plain)
                    divider
                    Link(destination: Links.privacy) {
                        linkLabel(icon: "hand.raised.fill", title: "Privacy policy", detail: nil)
                    }
                    .buttonStyle(.plain)
                    divider
                    Button {
                        requestReview()
                    } label: {
                        linkLabel(icon: "star.fill", title: "Rate \(Brand.plainName)", detail: nil)
                    }
                    .buttonStyle(.plain)
                    divider
                    row {
                        Text("Version")
                            .font(.barlow(16, weight: .medium))
                            .foregroundStyle(Color.textMain)
                        Spacer()
                        Text(versionString)
                            .font(.barlow(15))
                            .foregroundStyle(Color.textDim)
                    }
                }
            }
            .padding(.horizontal, Layout.screenPad)
            .padding(.bottom, Layout.tabBarClearance)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            name = profile?.name == "ATHLETE" ? "" : (profile?.name ?? "")
            csv = DataExport.csv(workouts)
            RestAlerts.status { notificationStatus = $0 }
        }
        .onDisappear(perform: saveName)
    }

    // MARK: Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .card(18)
        }
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 58)
    }

    private var divider: some View {
        Divider().overlay(Color.hairlineSoft).padding(.leading, 16)
    }

    private func stepperRow(title: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        row {
            Text(title)
                .font(.barlow(16, weight: .medium))
                .foregroundStyle(Color.textMain)
            Spacer()
            HStack(spacing: 10) {
                stepButton("minus", action: minus)
                Text(value)
                    .font(.condensed(19, weight: .bold))
                    .foregroundStyle(Color.textMain)
                    .monospacedDigit()
                    .frame(minWidth: 92)
                stepButton("plus", action: plus)
            }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.selection()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.textSoft)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.surface2))
                .frame(width: Layout.minTap, height: Layout.minTap)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private func toggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.barlow(16, weight: .medium))
                    .foregroundStyle(Color.textMain)
                Text(detail)
                    .font(.barlow(13))
                    .foregroundStyle(Color.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.purplePrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func linkLabel(icon: String, title: String, detail: String?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.purpleBright)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.barlow(16, weight: .medium))
                    .foregroundStyle(Color.textMain)
                if let detail {
                    Text(detail)
                        .font(.barlow(13))
                        .foregroundStyle(Color.textDim)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textFaint)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    // MARK: Behaviour

    private var restAlertDetail: String {
        "A sound and a banner when rest is over, even with your phone locked."
    }

    private func setRestAlerts(_ on: Bool) {
        Prefs.shared.setRestAlerts(on)
        guard on else { return }
        if notificationStatus == .notDetermined {
            RestAlerts.request { _ in
                RestAlerts.status { notificationStatus = $0 }
            }
        }
    }

    private func saveName() {
        guard let profile else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.name = trimmed.isEmpty ? "ATHLETE" : trimmed
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
