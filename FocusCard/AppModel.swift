import FamilyControls
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let store = SharedStore()
    private let scanner = NFCScanner()

    var night = FocusMode(name: "Night")
    var cards: [PairedCard] = []
    var sessions: [FocusSession] = []
    var lock: LockState?
    var emergencyAllowance = 3
    var onboarded = false
    var isAuthorized = false
    var alertMessage: String?
    var recoveryWaitEnd: Date?
    var recoveryCode: String?

    init() {
        reload()
    }

    func reload() {
        finishRecoveryWaitIfDue()
        recoveryWaitEnd = store.recoveryWaitEnd
        recoveryCode = store.recoveryCode
        night = store.night
        cards = store.cards
        sessions = store.sessions
        lock = store.lock
        emergencyAllowance = store.emergencyAllowance
        onboarded = store.onboarded
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    // MARK: Night routine

    /// Saves bedtime, wake time and blocked apps, and re-arms the schedule.
    func saveNight(_ mode: FocusMode) {
        store.night = mode
        FocusSchedule.sync(mode)
        Task { await WakeAlarm.sync(mode) }
        reload()
    }

    var isNightLock: Bool { lock?.night == true }

    /// True after wake time, while the morning protection hours are still running.
    func isInMorningProtection(at date: Date = .now) -> Bool {
        guard let lock, lock.night == true, let end = lock.wakeAt else { return false }
        return date >= end.addingTimeInterval(-Double(night.morningHours) * 3600) && date < end
    }

    /// True while a night lock is still before its wake time: the card does nothing yet.
    func cardIsHeld(at date: Date = .now) -> Bool {
        guard let lock, lock.night == true, let wake = lock.wakeAt else { return false }
        return date < wake
    }

    // MARK: Screen Time access

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            alertMessage = "Screen Time access was not granted. You can allow it in Settings."
        }
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func completeOnboarding() {
        store.onboarded = true
        onboarded = true
    }

    // MARK: Cards

    @discardableResult
    func pairCard() async -> Bool {
        do {
            let id = try await scanner.scan(
                prompt: "Hold your card near the top of the iPhone.",
                success: "Card paired."
            )
            if cards.contains(where: { $0.tagID == id }) {
                alertMessage = "This card is already paired."
                return false
            }
            var all = cards
            all.append(PairedCard(tagID: id, name: "Card \(all.count + 1)"))
            store.cards = all
            reload()
            return true
        } catch {
            handle(error)
            return false
        }
    }

    func removeCards(at offsets: IndexSet) {
        var all = cards
        all.remove(atOffsets: offsets)
        store.cards = all
        reload()
    }

    // MARK: Lock and unlock

    /// Daytime "Lock now": same apps, card works any time.
    func lockNow() async {
        guard !night.isEmpty else {
            alertMessage = "Choose apps to block first."
            return
        }
        guard !cards.isEmpty else {
            alertMessage = "Pair a card first."
            return
        }
        let paired = Set(cards.map(\.tagID))
        do {
            _ = try await scanner.scan(
                prompt: "Hold your card near the top of the iPhone to lock.",
                success: "Locked.",
                accept: { paired.contains($0) }
            )
            FocusEngine.lock(night, night: false, store: store)
            reload()
        } catch {
            handle(error)
        }
    }

    func unlockWithCard() async {
        guard let lock else { return }
        if cardIsHeld(), let wake = lock.wakeAt {
            alertMessage = "Your card works after \(wake.formatted(date: .omitted, time: .shortened)). If you need your phone now, use an emergency unlock."
            return
        }
        let paired = Set(cards.map(\.tagID))
        do {
            _ = try await scanner.scan(
                prompt: "Hold your card near the top of the iPhone to unlock.",
                success: "Unlocked.",
                accept: { paired.contains($0) }
            )
            FocusEngine.unlock(emergency: false, store: store)
            reload()
        } catch {
            handle(error)
        }
    }

    // MARK: Emergency unlocks (Decisions 3, 5, 10, 11)

    var emergencyUsedThisWeek: Int {
        let weekStart = Calendar.startOfFocusWeek()
        return sessions.filter { $0.emergency && $0.end >= weekStart }.count
    }

    var emergencyLeft: Int { max(0, emergencyAllowance - emergencyUsedThisWeek) }

    func emergencyUnlock() {
        guard emergencyLeft > 0 else { return }
        FocusEngine.unlock(emergency: true, store: store)
        reload()
    }

    func setEmergencyAllowance(_ value: Int) {
        store.emergencyAllowance = value
        emergencyAllowance = value
    }

    // MARK: Lost card recovery (neither way uses an emergency unlock)

    /// Makes the recovery code once, like FC-7K4M-92QX.
    func ensureRecoveryCode() {
        guard store.recoveryCode == nil else { return }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        func chunk() -> String { String((0..<4).map { _ in alphabet.randomElement() ?? "X" }) }
        store.recoveryCode = "FC-\(chunk())-\(chunk())"
        recoveryCode = store.recoveryCode
    }

    /// Returns false when the code is wrong.
    @discardableResult
    func unlockWithRecoveryCode(_ input: String) -> Bool {
        func normal(_ s: String) -> String {
            s.uppercased().filter { $0.isLetter || $0.isNumber }
        }
        guard lock != nil, let code = store.recoveryCode, normal(input) == normal(code) else { return false }
        FocusEngine.unlock(emergency: false, store: store)
        reload()
        alertMessage = "Unlocked. Pair a replacement card in Cards."
        return true
    }

    func startRecoveryWait() {
        guard lock != nil, store.recoveryWaitEnd == nil else { return }
        store.recoveryWaitEnd = Date.now.addingTimeInterval(24 * 60 * 60)
        recoveryWaitEnd = store.recoveryWaitEnd
    }

    func cancelRecoveryWait() {
        store.recoveryWaitEnd = nil
        recoveryWaitEnd = nil
    }

    /// Unlocks by itself once the 24 hours are up.
    func finishRecoveryWaitIfDue() {
        guard store.lock != nil, let end = store.recoveryWaitEnd, end <= .now else { return }
        FocusEngine.unlock(emergency: false, store: store)
        lock = store.lock
        recoveryWaitEnd = nil
        sessions = store.sessions
    }

    // MARK: Night stats

    struct NightStats {
        var nightsCompleted: Int
        var emergencyUsed: Int
        var streak: Int
        var averageHoursLocked: Double
    }

    func nightStats(days: Int) -> NightStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let nights = sessions.filter { $0.night == true && $0.end >= start }
        let done = nights.filter { !$0.emergency }
        let hours = done.isEmpty ? 0 : done.reduce(0) { $0 + $1.duration } / Double(done.count) / 3600
        return NightStats(
            nightsCompleted: done.count,
            emergencyUsed: nights.filter(\.emergency).count,
            streak: streak(),
            averageHoursLocked: hours
        )
    }

    /// Mornings in a row, up to today, that ended a night lock with the card.
    func streak() -> Int {
        let calendar = Calendar.current
        let days = Set(sessions.filter { $0.night == true && !$0.emergency }.map { calendar.startOfDay(for: $0.end) })
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var count = 0
        while days.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    /// Last seven days, oldest first: did that morning end a night lock with the card?
    func lastSevenNights() -> [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let done = Set(sessions.filter { $0.night == true && !$0.emergency }.map { calendar.startOfDay(for: $0.end) })
        return (0..<7).reversed().map { back in
            done.contains(calendar.date(byAdding: .day, value: -back, to: today) ?? today)
        }
    }

    // MARK: Errors

    private func handle(_ error: Error) {
        if let scanError = error as? NFCScanner.ScanError {
            // Cancelled and rejected scans already explain themselves on the sheet.
            if case .unavailable = scanError { alertMessage = scanError.errorDescription }
            return
        }
        alertMessage = error.localizedDescription
    }
}
