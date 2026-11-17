import Foundation

/// Reads and writes app state in the App Group, so the app and the shield
/// extension see the same data.
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

    var mode: FocusMode {
        get { load("workMode") ?? FocusMode() }
        set { save(newValue, "workMode") }
    }

    var card: PairedCard? {
        get { load("card") }
        set { save(newValue, "card") }
    }

    var lock: LockState? {
        get { load("lockState") }
        set { save(newValue, "lockState") }
    }

    /// Emergency unlocks allowed each week (Monday to Sunday). Default 5.
    var emergencyAllowance: Int {
        get { defaults.object(forKey: "emergencyAllowance") as? Int ?? 5 }
        set { defaults.set(newValue, forKey: "emergencyAllowance") }
    }

    /// When each emergency unlock was used.
    var emergencyUses: [Date] {
        get { load("emergencyUses") ?? [] }
        set { save(newValue, "emergencyUses") }
    }

    /// SHA-256 of the recovery code. The code itself is shown once and never stored.
    var recoveryCodeHash: String? {
        get { defaults.string(forKey: "recoveryCodeHash") }
        set { defaults.set(newValue, forKey: "recoveryCodeHash") }
    }
}

extension Calendar {
    /// Emergency unlocks refill every Monday.
    static func startOfFocusWeek(for date: Date = .now) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
