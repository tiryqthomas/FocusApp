import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

extension ManagedSettingsStore.Name {
    static let focusCard = Self("focuscard")
}

/// Locks and unlocks. Used by the app and by the bedtime monitor extension.
enum FocusEngine {
    static let settings = ManagedSettingsStore(named: .focusCard)

    /// `night` true: the bedtime lock, which the card can only end after wake time.
    static func lock(_ mode: FocusMode, night: Bool, store: SharedStore = SharedStore()) {
        let selection = mode.selection
        settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        settings.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.recoveryWaitEnd = nil
        store.lock = LockState(
            modeID: mode.id,
            modeName: night ? "Night" : "Locked",
            since: .now,
            night: night,
            wakeAt: night ? mode.nextWake() : nil
        )
    }

    static func unlock(emergency: Bool, store: SharedStore = SharedStore()) {
        settings.clearAllSettings()
        store.recoveryWaitEnd = nil
        guard let lock = store.lock else { return }
        var sessions = store.sessions
        sessions.append(FocusSession(modeName: lock.modeName, start: lock.since, end: .now, emergency: emergency, night: lock.night))
        store.sessions = sessions
        store.lock = nil
    }
}

/// Bedtime lock, started by iOS through DeviceActivity with no tap needed.
enum FocusSchedule {
    static let activity = DeviceActivityName("night")

    /// Replaces the schedule with the current bedtime. The interval runs from
    /// bedtime to wake time; the lock itself stays on until a card (or an
    /// emergency unlock) ends it.
    static func sync(_ night: FocusMode) {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
        guard night.scheduleEnabled, !night.isEmpty else { return }
        let start = DateComponents(hour: night.startHour, minute: night.startMinute)
        let end = DateComponents(hour: night.wakeHour, minute: night.wakeMinute)
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
        try? center.startMonitoring(activity, during: schedule)
    }
}
