import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

extension ManagedSettingsStore.Name {
    static let focusCard = Self("focuscard")
}

/// Locks and unlocks modes. Used by the app and by the schedule monitor extension.
enum FocusEngine {
    static let settings = ManagedSettingsStore(named: .focusCard)

    static func lock(_ mode: FocusMode, store: SharedStore = SharedStore()) {
        let selection = mode.selection
        settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        settings.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.recoveryWaitEnd = nil
        store.lock = LockState(modeID: mode.id, modeName: mode.name, since: .now)
    }

    static func unlock(emergency: Bool, store: SharedStore = SharedStore()) {
        settings.clearAllSettings()
        store.recoveryWaitEnd = nil
        guard let lock = store.lock else { return }
        var sessions = store.sessions
        sessions.append(FocusSession(modeName: lock.modeName, start: lock.since, end: .now, emergency: emergency))
        store.sessions = sessions
        store.lock = nil
    }
}

/// Decision 6: scheduled starts, through DeviceActivity.
enum FocusSchedule {
    private static let prefix = "mode."

    static func activityName(for mode: FocusMode) -> DeviceActivityName {
        DeviceActivityName(prefix + mode.id.uuidString)
    }

    static func modeID(from activity: DeviceActivityName) -> UUID? {
        guard activity.rawValue.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(activity.rawValue.dropFirst(prefix.count)))
    }

    /// Replaces every schedule with the current modes' schedules.
    /// The interval end only bounds the monitor's window: the lock itself
    /// stays on until a card (or an emergency unlock) ends it.
    static func sync(_ modes: [FocusMode]) {
        let center = DeviceActivityCenter()
        center.stopMonitoring()
        for mode in modes where mode.scheduleEnabled && !mode.isEmpty {
            let start = DateComponents(hour: mode.startHour, minute: mode.startMinute)
            let end = DateComponents(hour: (mode.startHour + 1) % 24, minute: mode.startMinute)
            let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: true)
            try? center.startMonitoring(activityName(for: mode), during: schedule)
        }
    }
}
