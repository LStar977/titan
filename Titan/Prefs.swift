import Foundation
import Observation

/// How the athlete reads weight. Every weight is stored in pounds; the unit
/// only changes what is shown and how typed values are read back.
enum WeightUnit: String, CaseIterable, Identifiable {
    case lb
    case kg

    var id: String { rawValue }

    static let kgPerLb = 0.45359237

    /// Stored pounds → this unit.
    func fromLb(_ lb: Double) -> Double {
        self == .lb ? lb : lb * WeightUnit.kgPerLb
    }

    /// A value typed in this unit → stored pounds.
    func toLb(_ value: Double) -> Double {
        self == .lb ? value : value / WeightUnit.kgPerLb
    }

    /// Stepper increment, in this unit.
    var step: Double { self == .lb ? 5 : 2.5 }

    /// Standard barbell, in this unit.
    var barWeight: Double { self == .lb ? 45 : 20 }

    var label: String { rawValue }
    var title: String { self == .lb ? "Pounds" : "Kilograms" }

    /// Body measurements follow the weight system: inches or centimetres.
    var lengthLabel: String { self == .lb ? "in" : "cm" }
    func fromInches(_ v: Double) -> Double { self == .lb ? v : v * 2.54 }
    func toInches(_ v: Double) -> Double { self == .lb ? v : v / 2.54 }

    /// Best guess for a brand-new athlete. Canadian gyms mostly load pounds
    /// even though the country is metric, so Canada defaults to lb.
    static var localeDefault: WeightUnit {
        if Locale.current.region?.identifier == "CA" { return .lb }
        return Locale.current.measurementSystem == .us ? .lb : .kg
    }
}

/// App-wide preferences, persisted in UserDefaults. Observable, so any view
/// that reads a preference (directly or through `Fmt`) refreshes when it changes.
@Observable
final class Prefs {
    static let shared = Prefs()

    private(set) var unit: WeightUnit
    private(set) var restAlerts: Bool
    private(set) var autoProgress: Bool
    private(set) var hasOnboarded: Bool

    private init() {
        let d = UserDefaults.standard
        unit = WeightUnit(rawValue: d.string(forKey: "titan.unit") ?? "") ?? .lb
        restAlerts = d.object(forKey: "titan.restAlerts") as? Bool ?? true
        autoProgress = d.object(forKey: "titan.autoProgress") as? Bool ?? true
        hasOnboarded = d.bool(forKey: "titan.onboarded")
    }

    func setUnit(_ value: WeightUnit) {
        unit = value
        UserDefaults.standard.set(value.rawValue, forKey: "titan.unit")
    }

    func setRestAlerts(_ value: Bool) {
        restAlerts = value
        UserDefaults.standard.set(value, forKey: "titan.restAlerts")
        if !value { RestAlerts.cancel() }
    }

    func setAutoProgress(_ value: Bool) {
        autoProgress = value
        UserDefaults.standard.set(value, forKey: "titan.autoProgress")
    }

    func setOnboarded(_ value: Bool) {
        hasOnboarded = value
        UserDefaults.standard.set(value, forKey: "titan.onboarded")
    }
}
