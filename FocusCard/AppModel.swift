import CryptoKit
import FamilyControls
import Foundation
import Observation

/// The core loop: pair a card, choose apps, scan to lock, scan again to unlock.
@MainActor
@Observable
final class AppModel {
    private let store = SharedStore()
    private let scanner = NFCScanner()

    var mode = FocusMode()
    var card: PairedCard?
    var lock: LockState?
    var isAuthorized = false
    var alertMessage: String?
    var emergencyAllowance = 5
    var emergencyUsedThisWeek = 0
    var hasRecoveryCode = false

    init() { reload() }

    func reload() {
        mode = store.mode
        card = store.card
        lock = store.lock
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        emergencyAllowance = store.emergencyAllowance
        let weekStart = Calendar.startOfFocusWeek()
        emergencyUsedThisWeek = store.emergencyUses.filter { $0 >= weekStart }.count
        hasRecoveryCode = store.recoveryCodeHash != nil
    }

    // MARK: Emergency unlocks

    var emergencyLeft: Int { max(0, emergencyAllowance - emergencyUsedThisWeek) }

    func emergencyUnlock() {
        guard lock != nil, emergencyLeft > 0 else { return }
        store.emergencyUses = store.emergencyUses + [.now]
        FocusEngine.unlock(store: store)
        reload()
    }

    /// Only reachable from Settings, which is only open while unlocked.
    func setEmergencyAllowance(_ value: Int) {
        guard lock == nil else { return }
        store.emergencyAllowance = value
        reload()
    }

    // MARK: Recovery code (card lost, or the scan won't work)

    /// Makes a new code like FC-7K4M-92QX, replacing any old one, and returns it.
    /// Only the hash is kept, so this is the only time the code can be seen.
    func makeRecoveryCode() -> String? {
        guard lock == nil else { return nil }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        func chunk() -> String { String((0..<4).map { _ in alphabet.randomElement()! }) }
        let code = "FC-\(chunk())-\(chunk())"
        store.recoveryCodeHash = Self.hash(code)
        reload()
        return code
    }

    /// Returns false when the code is wrong. Doesn't use an emergency unlock.
    func unlockWithRecoveryCode(_ input: String) -> Bool {
        guard lock != nil, let saved = store.recoveryCodeHash, Self.hash(input) == saved else { return false }
        FocusEngine.unlock(store: store)
        reload()
        return true
    }

    /// Ignores case, spaces and dashes.
    private static func hash(_ code: String) -> String {
        let normal = code.uppercased().filter { $0.isLetter || $0.isNumber }
        return SHA256.hash(data: Data(normal.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            alertMessage = "Screen Time access was not granted. You can allow it in Settings."
        }
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func saveSelection(_ selection: FamilyActivitySelection) {
        var updated = mode
        updated.selection = selection
        store.mode = updated
        reload()
    }

    /// Pairs a card, replacing any card paired before.
    func pairCard() async {
        guard lock == nil else { return }
        do {
            let id = try await scanner.scan(
                prompt: "Hold your card near the top of the iPhone.",
                success: "Card paired.",
                writeIfBlank: true
            )
            store.card = PairedCard(tagID: id)
            reload()
        } catch {
            handle(error)
        }
    }

    /// One scan toggles: locks when unlocked, unlocks when locked.
    func scanToToggle() async {
        guard let card else {
            alertMessage = "Pair a card first."
            return
        }
        if lock == nil {
            guard isAuthorized else {
                alertMessage = "Allow Screen Time access first."
                return
            }
            guard !mode.isEmpty else {
                alertMessage = "Choose apps to block first."
                return
            }
        }
        let locking = lock == nil
        do {
            _ = try await scanner.scan(
                prompt: locking ? "Hold your card near the top of the iPhone to lock." : "Hold your card near the top of the iPhone to unlock.",
                success: locking ? "Locked." : "Unlocked.",
                accept: { $0 == card.tagID }
            )
            print("[FocusCard] card accepted, \(locking ? "locking" : "unlocking")")
            if locking {
                FocusEngine.lock(mode, store: store)
            } else {
                FocusEngine.unlock(store: store)
            }
            reload()
            print("[FocusCard] locked state now: \(lock != nil)")
        } catch {
            handle(error)
        }
    }

    /// Opened from the card's link: the card was tapped while no scan was running
    /// (iOS reads it in the background and offers to open Focus Card).
    /// Locking and unlocking still need the button, so explain that.
    func handleCardLink(_ url: URL) async {
        guard url.scheme == "focuscard", url.host == "card" else { return }
        reload()
        print("[FocusCard] card tapped outside a scan: \(url)")
        alertMessage = lock != nil
            ? "Card tapped, but Focus Card wasn't scanning. Tap Scan card to unlock first, then hold your card to the top of the iPhone."
            : "Card tapped, but Focus Card wasn't scanning. Tap Scan card to lock first, then hold your card to the top of the iPhone."
    }

    private func handle(_ error: Error) {
        if let scanError = error as? NFCScanner.ScanError {
            // While testing, every failure except a plain cancel shows in the app too,
            // and goes to the Xcode console.
            print("[FocusCard] scan failed: \(scanError)")
            if let text = scanError.errorDescription { alertMessage = text }
            return
        }
        print("[FocusCard] scan error: \(error)")
        alertMessage = error.localizedDescription
    }
}
