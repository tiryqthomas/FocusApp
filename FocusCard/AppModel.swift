import FamilyControls
import Foundation
import Observation

/// The core loop: pair a card, choose apps, scan to lock, scan again to unlock.
@MainActor
@Observable
final class AppModel {
    private let store = SharedStore()
    private let scanner = NFCScanner()

    var modes: [FocusMode] = []
    var selectedModeID: UUID?
    var card: PairedCard?
    var lock: LockState?
    var isAuthorized = false
    var alertMessage: String?
    var emergency = EmergencyAllowance()
    var focusLog = FocusLog()
    var appearance: Appearance = .system
    var recoveryCode = ""
    var recoveryCodeSaved = false
    /// Shown once per launch until the recovery code is saved.
    var showSaveRecovery = false

    init() { reload() }

    func reload() {
        modes = store.modes
        selectedModeID = store.selectedModeID.flatMap { id in modes.contains { $0.id == id } ? id : nil } ?? modes.first?.id
        card = store.card
        lock = store.lock
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        var allowance = store.emergency
        allowance.refillIfNewWeek()
        store.emergency = allowance
        emergency = allowance
        focusLog = store.focusLog
        appearance = store.appearance
        recoveryCode = store.recoveryCode
        recoveryCodeSaved = store.recoveryCodeSaved
    }

    /// Offers to save the recovery code, once per launch, until it's saved.
    func offerRecoverySaveIfNeeded() {
        if !recoveryCodeSaved && lock == nil { showSaveRecovery = true }
    }

    func markRecoveryCodeSaved() {
        store.recoveryCodeSaved = true
        reload()
    }

    func setAppearance(_ value: Appearance) {
        store.appearance = value
        reload()
    }

    /// Emergency unlocks per week, 0 to 10. Raising it adds to this week's remaining.
    func setEmergencyPerWeek(_ value: Int) {
        var allowance = store.emergency
        allowance.perWeek = min(10, max(0, value))
        allowance.used = min(allowance.used, allowance.perWeek)
        store.emergency = allowance
        reload()
    }

    /// Today's locked time, including the session running now.
    func focusedToday(now: Date = .now) -> Double {
        var total = focusLog.seconds(on: now)
        if let lock {
            let start = max(lock.since, Calendar.current.startOfDay(for: now))
            total += max(0, now.timeIntervalSince(start))
        }
        return total
    }

    /// Mon to Sun of this week, in seconds, including the running session.
    func focusedThisWeek(now: Date = .now) -> Double {
        let calendar = Calendar.current
        let monday = EmergencyAllowance.mondayOfThisWeek(now)
        var total = 0.0
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday), day <= now else { continue }
            total += focusLog.seconds(on: day)
        }
        if let lock { total += max(0, now.timeIntervalSince(max(lock.since, monday))) }
        return total
    }

    /// Uses one emergency unlock. The caller has already asked "Are you sure?".
    func emergencyUnlock() {
        guard lock != nil, emergency.remaining > 0 else { return }
        var allowance = store.emergency
        allowance.used += 1
        store.emergency = allowance
        endLock(.emergency)
    }

    /// Unlocks with the recovery code. Doesn't use an emergency unlock.
    /// Returns false when the code doesn't match.
    func unlockWithRecovery(_ entered: String) -> Bool {
        let cleaned = entered.uppercased().filter { !$0.isWhitespace }
        guard lock != nil, cleaned == recoveryCode else { return false }
        endLock(.recovery)
        return true
    }

    private func endLock(_ method: UnlockMethod) {
        if let lock {
            var log = store.focusLog
            log.add(from: lock.since, to: .now)
            if method == .card { log.cardUnlocks += 1 }
            store.focusLog = log
        }
        FocusEngine.unlock(store: store)
        reload()
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            alertMessage = "Screen Time access was not granted. You can allow it in Settings."
        }
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: Modes

    /// The mode the Lock button locks.
    var mode: FocusMode { modes.first { $0.id == selectedModeID } ?? modes.first ?? FocusMode() }

    func select(_ mode: FocusMode) {
        guard lock == nil else { return }
        store.selectedModeID = mode.id
        reload()
    }

    /// Adds a mode or replaces the one with the same id.
    func saveMode(_ mode: FocusMode) {
        var all = modes
        if let index = all.firstIndex(where: { $0.id == mode.id }) {
            all[index] = mode
        } else {
            all.append(mode)
            store.selectedModeID = mode.id
        }
        store.modes = all
        reload()
    }

    func deleteMode(_ mode: FocusMode) {
        guard lock == nil, modes.count > 1 else { return }
        store.modes = modes.filter { $0.id != mode.id }
        reload()
    }

    func saveSelection(_ selection: FamilyActivitySelection, for modeID: UUID) {
        guard var updated = modes.first(where: { $0.id == modeID }) else { return }
        updated.selection = selection
        saveMode(updated)
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
                alertMessage = "Choose apps to block for \(mode.name) first."
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
                endLock(.card)
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
