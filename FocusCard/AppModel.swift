import FamilyControls
import Foundation
import Observation
import UserNotifications

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
    var appearance: Appearance = .dark
    var hapticsOn = true
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
        hapticsOn = store.hapticsOn
        recoveryCode = store.recoveryCode
        recoveryCodeSaved = store.recoveryCodeSaved
        // The 24-hour wait ends the next time the app runs after it's up.
        if let releaseAt = lock?.releaseAt, releaseAt <= .now {
            endLock(.wait, at: releaseAt)
        }
    }

    static let waitLength: TimeInterval = 24 * 60 * 60
    private static let waitNotificationID = "focuscard.wait"

    /// Last resort with no card and no password: the lock ends by itself in 24 hours.
    /// The date and time stay automatic while locked, so the clock can't be moved ahead.
    func startWait() async {
        guard var current = store.lock, current.releaseAt == nil else { return }
        let releaseAt = Date.now.addingTimeInterval(Self.waitLength)
        current.releaseAt = releaseAt
        store.lock = current
        reload()

        // A reminder when the time is up, since the shield only lifts once the app opens.
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        let content = UNMutableNotificationContent()
        content.title = "Focus Card"
        content.body = "Your 24-hour wait is over. Open Focus Card to unlock your apps."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.waitLength, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.waitNotificationID, content: content, trigger: trigger))
    }

    func cancelWait() {
        guard var current = store.lock, current.releaseAt != nil else { return }
        current.releaseAt = nil
        store.lock = current
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.waitNotificationID])
        reload()
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

    func setHaptics(_ on: Bool) {
        store.hapticsOn = on
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

    /// Locked seconds for each day Mon to Sun of this week (today includes the running session).
    func focusedByDayThisWeek(now: Date = .now) -> [Double] {
        let calendar = Calendar.current
        let monday = EmergencyAllowance.mondayOfThisWeek(now)
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return 0 }
            if calendar.isDate(day, inSameDayAs: now) { return focusedToday(now: now) }
            return day > now ? 0 : focusLog.seconds(on: day)
        }
    }

    /// Locked seconds over the same weekdays of last week, for "vs last week".
    func focusedLastWeekSoFar(now: Date = .now) -> Double {
        let calendar = Calendar.current
        let monday = EmergencyAllowance.mondayOfThisWeek(now)
        let todayIndex = calendar.dateComponents([.day], from: monday, to: calendar.startOfDay(for: now)).day ?? 0
        return (0...max(0, todayIndex)).reduce(0) { total, offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 7, to: monday) else { return total }
            return total + focusLog.seconds(on: day)
        }
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

    private func endLock(_ method: UnlockMethod, at end: Date = .now) {
        if lock?.releaseAt != nil, method != .wait {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.waitNotificationID])
        }
        if let lock {
            var log = store.focusLog
            log.add(from: lock.since, to: end)
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
