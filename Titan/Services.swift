import Foundation
import SwiftUI
import UserNotifications
import UniformTypeIdentifiers

// MARK: - Rest alerts

/// Local notifications for the rest timer, so the athlete hears about it even
/// with the phone locked or another app open. Nothing leaves the device.
enum RestAlerts {
    private static let id = "titan.rest"

    /// Asks once. Safe to call repeatedly — it does nothing after the first answer.
    static func requestIfNeeded() {
        guard Prefs.shared.restAlerts else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Always shows the system prompt if it hasn't been answered, and reports the result.
    static func request(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func status(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    static func schedule(at date: Date, title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard Prefs.shared.restAlerts else { return }
        let interval = date.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }
}

/// While the app is open, a rest alert plays its sound but skips the banner —
/// the in-app rest dock already shows it.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.sound])
    }
}

// MARK: - Review prompt

/// Asks for an App Store rating at a high point — right after a workout with a
/// record in it — and never more than once every four months.
enum ReviewGate {
    private static let prKey = "titan.review.prWorkouts"
    private static let askedKey = "titan.review.lastAsked"

    /// Records a finished workout; returns true when now is a good moment to ask.
    static func recordFinished(hadPR: Bool) -> Bool {
        guard hadPR else { return false }
        let d = UserDefaults.standard
        let count = d.integer(forKey: prKey) + 1
        d.set(count, forKey: prKey)
        guard count >= 2 else { return false }
        if let last = d.object(forKey: askedKey) as? Date,
           Date().timeIntervalSince(last) < 120 * 86400 {
            return false
        }
        d.set(Date(), forKey: askedKey)
        return true
    }
}

// MARK: - Plate math

enum PlateMath {
    /// Plates available per side, heaviest first, in the given unit.
    static func plates(for unit: WeightUnit) -> [Double] {
        unit == .lb ? [45, 35, 25, 10, 5, 2.5] : [25, 20, 15, 10, 5, 2.5, 1.25]
    }

    /// Greedy plate breakdown for one side of the bar. Values in display units.
    static func perSide(target: Double, bar: Double, unit: WeightUnit) -> (plates: [Double], remainder: Double) {
        var remaining = max(0, (target - bar) / 2)
        var out: [Double] = []
        for p in plates(for: unit) {
            while remaining + 0.0001 >= p {
                out.append(p)
                remaining -= p
            }
        }
        return (out, max(0, remaining))
    }

    /// "Per side: 45 + 25 + 5" for a stored-pound barbell weight, or nil when
    /// the weight is lighter than an empty bar.
    static func summary(lb: Double) -> String? {
        let unit = Prefs.shared.unit
        let target = unit.fromLb(lb)
        let bar = unit.barWeight
        guard target >= bar - 0.01 else { return nil }
        let result = perSide(target: target, bar: bar, unit: unit)
        if result.plates.isEmpty { return "Just the bar" }
        return "Per side: " + result.plates.map { Fmt.num($0) }.joined(separator: " + ")
    }
}

// MARK: - Data export

enum DataExport {
    /// Every logged set as CSV, oldest first, weights in the athlete's unit.
    static func csv(_ workouts: [Workout]) -> String {
        let unit = Prefs.shared.unit
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        var lines = ["date,workout,exercise,set,type,weight_\(unit.label),reps,volume_\(unit.label),pr,notes"]
        let finished = workouts
            .filter { $0.endedAt != nil }
            .sorted { $0.startedAt < $1.startedAt }
        for w in finished {
            let date = dateFormatter.string(from: w.startedAt)
            for entry in w.sortedEntries {
                var n = 0
                for s in entry.sortedSets where s.isCompleted {
                    n += 1
                    let fields = [
                        date,
                        w.title,
                        entry.displayName,
                        "\(n)",
                        s.type.rawValue,
                        Fmt.num(unit.fromLb(s.weight)),
                        "\(s.reps)",
                        Fmt.num(unit.fromLb(Stats.setVolume(s)), decimals: 1),
                        s.isPR ? "1" : "0",
                        entry.notes
                    ]
                    lines.append(fields.map(escape).joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func escape(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// A CSV the share sheet can save or send. The text is built on the main
/// actor beforehand; this only writes it to a temporary file.
struct CSVFile: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Brand.plainName)-workouts.csv")
            try file.text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
