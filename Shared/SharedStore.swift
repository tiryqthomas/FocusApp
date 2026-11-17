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

    /// All modes. The first launch after the update carries the old single
    /// Work mode over, and adds Sleep.
    var modes: [FocusMode] {
        get {
            if let modes: [FocusMode] = load("modes"), !modes.isEmpty { return modes }
            let work: FocusMode = load("workMode") ?? FocusMode()
            let initial = [work, FocusMode(name: "Sleep", symbol: "moon.fill")]
            save(initial, "modes") // so ids stay the same from here on
            return initial
        }
        set { save(newValue, "modes") }
    }

    var selectedModeID: UUID? {
        get { load("selectedModeID") }
        set { save(newValue, "selectedModeID") }
    }

    /// Name of the locked mode, for the shield. Kept as plain text so the shield
    /// extension reads it quickly.
    var lockedModeName: String? {
        get { defaults.string(forKey: "lockedModeName") }
        set { defaults.set(newValue, forKey: "lockedModeName") }
    }

    var card: PairedCard? {
        get { load("card") }
        set { save(newValue, "card") }
    }

    var lock: LockState? {
        get { load("lockState") }
        set { save(newValue, "lockState") }
    }

    var emergency: EmergencyAllowance {
        get { load("emergency") ?? EmergencyAllowance() }
        set { save(newValue, "emergency") }
    }

    /// Made once, on first launch. Unlocks without the card.
    var recoveryCode: String {
        if let code: String = load("recoveryCode") { return code }
        let code = Self.makeRecoveryCode()
        save(code, "recoveryCode")
        return code
    }

    var recoveryCodeSaved: Bool {
        get { load("recoveryCodeSaved") ?? false }
        set { save(newValue, "recoveryCodeSaved") }
    }

    var focusLog: FocusLog {
        get { load("focusLog") ?? FocusLog() }
        set { save(newValue, "focusLog") }
    }

    /// Dark unless changed in Settings.
    var appearance: Appearance {
        get { load("appearance") ?? .dark }
        set { save(newValue, "appearance") }
    }

    var hapticsOn: Bool {
        get { load("hapticsOn") ?? true }
        set { save(newValue, "hapticsOn") }
    }

    /// "FC-7K2M-9QXD". Leaves out 0, O, 1 and I so it's easy to read back.
    static func makeRecoveryCode() -> String {
        let letters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        func group() -> String { String((0..<4).map { _ in letters.randomElement()! }) }
        return "FC-\(group())-\(group())"
    }
}
