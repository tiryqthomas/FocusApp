import CoreNFC
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

    /// Opened from the card's link (iOS reads the card in the background and offers
    /// to open Focus Card). Toggles the lock if the link belongs to the paired card.
    func handleCardLink(_ url: URL) async {
        guard url.scheme == "focuscard", url.host == "card" else { return }
        guard let card,
              let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)?.payload,
              payload.map({ String(format: "%02X", $0) }).joined() == card.tagID
        else {
            print("[FocusCard] link from an unpaired card: \(url)")
            alertMessage = NFCScanner.ScanError.rejected.errorDescription
            return
        }
        reload()
        if lock != nil {
            FocusEngine.unlock(store: store)
        } else {
            guard isAuthorized, !mode.isEmpty else {
                alertMessage = "Allow Screen Time and choose apps first."
                return
            }
            FocusEngine.lock(mode, store: store)
        }
        reload()
        print("[FocusCard] card link toggled, locked now: \(lock != nil)")
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
