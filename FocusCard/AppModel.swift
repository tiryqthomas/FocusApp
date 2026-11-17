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

    init() { reload() }

    func reload() {
        mode = store.mode
        card = store.card
        lock = store.lock
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
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
                success: "Card paired."
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
            if locking {
                FocusEngine.lock(mode, store: store)
            } else {
                FocusEngine.unlock(store: store)
            }
            reload()
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        if let scanError = error as? NFCScanner.ScanError {
            // Cancelled and rejected scans already explain themselves on the sheet.
            if case .unavailable = scanError { alertMessage = scanError.errorDescription }
            return
        }
        alertMessage = error.localizedDescription
    }
}
