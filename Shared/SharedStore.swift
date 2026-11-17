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
}
