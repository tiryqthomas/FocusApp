import Foundation
import FamilyControls
import ManagedSettings

extension ManagedSettingsStore.Name {
    static let focusCard = Self("focuscard")
}

/// Turns the shield on and off. iOS keeps these settings in force when the
/// app is closed and after a restart, until the app clears them.
enum FocusEngine {
    static let settings = ManagedSettingsStore(named: .focusCard)

    static func lock(_ mode: FocusMode, store: SharedStore = SharedStore()) {
        let selection = mode.selection
        settings.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        settings.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        settings.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        // Bypass fix: while locked, apps (including Focus Card) can't be deleted,
        // since deleting Focus Card would clear the shield.
        settings.application.denyAppRemoval = true
        // Bypass fix: the date and time must stay automatic while locked.
        settings.dateAndTime.requireAutomaticDateAndTime = true
        store.lock = LockState(modeName: mode.name, since: .now)
    }

    static func unlock(store: SharedStore = SharedStore()) {
        settings.clearAllSettings()
        store.lock = nil
    }
}
