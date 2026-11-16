import FamilyControls
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    private let store = SharedStore()
    private let scanner = NFCScanner()

    var modes: [FocusMode] = []
    var cards: [PairedCard] = []
    var sessions: [FocusSession] = []
    var lock: LockState?
    var emergencyAllowance = 5
    var onboarded = false
    var isAuthorized = false
    var selectedModeID: UUID?
    var alertMessage: String?
    var recoveryWaitEnd: Date?
    var recoveryCode: String?

    init() {
        if !store.didCreateDefaultModes {
            store.modes = [FocusMode(name: "Work"), FocusMode(name: "Sleep")]
            store.didCreateDefaultModes = true
        }
        reload()
    }

    func reload() {
        finishRecoveryWaitIfDue()
        recoveryWaitEnd = store.recoveryWaitEnd
        recoveryCode = store.recoveryCode
        modes = store.modes
        cards = store.cards
        sessions = store.sessions
        lock = store.lock
        emergencyAllowance = store.emergencyAllowance
        onboarded = store.onboarded
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if selectedModeID == nil || !modes.contains(where: { $0.id == selectedModeID }) {
            selectedModeID = modes.first?.id
        }
    }

    // MARK: Modes

    var selectedMode: FocusMode? { modes.first { $0.id == selectedModeID } }

    var lockedMode: FocusMode? {
        guard let lock else { return nil }
        return modes.first { $0.id == lock.modeID }
    }

    func saveMode(_ mode: FocusMode) {
        var all = modes
        if let index = all.firstIndex(where: { $0.id == mode.id }) {
            all[index] = mode
        } else {
            all.append(mode)
            selectedModeID = mode.id
        }
        store.modes = all
        FocusSchedule.sync(all)
        reload()
    }

    func deleteMode(_ mode: FocusMode) {
        guard lock?.modeID != mode.id else {
            alertMessage = "\(mode.name) is locked. Unlock it before deleting it."
            return
        }
        let all = modes.filter { $0.id != mode.id }
        store.modes = all
        FocusSchedule.sync(all)
        reload()
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

    func lockSelected() async {
        guard let mode = selectedMode else { return }
        guard !mode.isEmpty else {
            alertMessage = "Choose apps for \(mode.name) first."
            return
        }
        guard !cards.isEmpty else {
            alertMessage = "Pair a card first."
            return
        }
        let paired = Set(cards.map(\.tagID))
        do {
            _ = try await scanner.scan(
                prompt: "Hold your card near the top of the iPhone to lock \(mode.name).",
                success: "\(mode.name) is locked.",
                accept: { paired.contains($0) }
            )
            FocusEngine.lock(mode, store: store)
            reload()
        } catch {
            handle(error)
        }
    }

    func unlockWithCard() async {
        guard let lock else { return }
        let paired = Set(cards.map(\.tagID))
        do {
            _ = try await scanner.scan(
                prompt: "Hold your card near the top of the iPhone to unlock \(lock.modeName).",
                success: "\(lock.modeName) is unlocked.",
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

    // MARK: Focus Card stats (Decision 14)

    struct FocusStats {
        var timeLocked: TimeInterval
        var previousTimeLocked: TimeInterval
        var emergencyUsed: Int
        var streakDays: Int
    }

    func focusStats(days: Int) -> FocusStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let currentStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today
        let previousStart = calendar.date(byAdding: .day, value: -days, to: currentStart) ?? currentStart

        let current = sessions.filter { $0.start >= currentStart }
        let previous = sessions.filter { $0.start >= previousStart && $0.start < currentStart }
        return FocusStats(
            timeLocked: current.reduce(0) { $0 + $1.duration },
            previousTimeLocked: previous.reduce(0) { $0 + $1.duration },
            emergencyUsed: current.filter(\.emergency).count,
            streakDays: streakDays()
        )
    }

    /// Days in a row, up to today, with at least one lock that ended with a card.
    private func streakDays() -> Int {
        let calendar = Calendar.current
        let days = Set(sessions.filter { !$0.emergency }.map { calendar.startOfDay(for: $0.end) })
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
