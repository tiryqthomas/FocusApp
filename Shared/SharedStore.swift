import Foundation

/// Reads and writes app state in the App Group, so the app and its
/// extensions (shield and schedule monitor) see the same data.
final class SharedStore {
    static let appGroupID = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""

    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    var modes: [FocusMode] {
        get { load("modes") ?? [] }
        set { save(newValue, "modes") }
    }

    var cards: [PairedCard] {
        get { load("cards") ?? [] }
        set { save(newValue, "cards") }
    }

    var sessions: [FocusSession] {
        get { load("sessions") ?? [] }
        set { save(newValue, "sessions") }
    }

    var lock: LockState? {
        get { load("lock") }
        set { save(newValue, "lock") }
    }

    /// Decision 5: 5 a week by default, editable in Settings.
    var emergencyAllowance: Int {
        get { defaults.object(forKey: "emergencyAllowance") as? Int ?? 5 }
        set { defaults.set(newValue, forKey: "emergencyAllowance") }
    }

    var onboarded: Bool {
        get { defaults.bool(forKey: "onboarded") }
        set { defaults.set(newValue, forKey: "onboarded") }
    }

    /// "I lost my card" code, made at setup. Using it never costs an emergency unlock.
    var recoveryCode: String? {
        get { defaults.string(forKey: "recoveryCode") }
        set { defaults.set(newValue, forKey: "recoveryCode") }
    }

    /// When the 24-hour recovery wait ends. Nil when no wait is running.
    var recoveryWaitEnd: Date? {
        get { defaults.object(forKey: "recoveryWaitEnd") as? Date }
        set {
            if let newValue { defaults.set(newValue, forKey: "recoveryWaitEnd") }
            else { defaults.removeObject(forKey: "recoveryWaitEnd") }
        }
    }

    var didCreateDefaultModes: Bool {
        get { defaults.bool(forKey: "didCreateDefaultModes") }
        set { defaults.set(newValue, forKey: "didCreateDefaultModes") }
    }
}

extension Calendar {
    /// Decision 10: emergency unlocks refill every Monday.
    static func startOfFocusWeek(for date: Date = .now) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
