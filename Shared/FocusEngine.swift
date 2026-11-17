import Foundation
import FamilyControls
import ManagedSettings

extension ManagedSettingsStore.Name {
    static let focusCard = Self("focuscard")
}

/// Turns the shield on and off. iOS keeps these settings in force when the
/// app is closed and after a restart, until the app clears them.
enum FocusEngine {
    /// iOS shields at most 50 apps and 50 websites per settings store and
    /// ignores the list past that, so long lists are spread over several stores.
    /// The first keeps its old name so existing locks still clear.
    static let perStore = 50
    static let stores: [ManagedSettingsStore] = (0..<8).map { index in
        ManagedSettingsStore(named: index == 0 ? .focusCard : ManagedSettingsStore.Name("focuscard-\(index)"))
    }
    static var settings: ManagedSettingsStore { stores[0] }

    static func lock(_ mode: FocusMode, store: SharedStore = SharedStore()) {
        let selection = mode.selection
        stores.forEach { $0.clearAllSettings() }

        let apps = chunks(Array(selection.applicationTokens))
        let sites = chunks(Array(selection.webDomainTokens))
        for (index, settingsStore) in stores.enumerated() {
            let appChunk = index < apps.count ? Set(apps[index]) : []
            let siteChunk = index < sites.count ? Set(sites[index]) : []
            settingsStore.shield.applications = appChunk.isEmpty ? nil : appChunk
            settingsStore.shield.webDomains = siteChunk.isEmpty ? nil : siteChunk
        }

        settings.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        settings.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        // Bypass fix: while locked, apps (including Focus Card) can't be deleted,
        // since deleting Focus Card would clear the shield.
        settings.application.denyAppRemoval = true
        // Bypass fix: the date and time must stay automatic while locked.
        settings.dateAndTime.requireAutomaticDateAndTime = true
        store.lockedModeName = mode.name
        store.lock = LockState(modeName: mode.name, since: .now)
        print("[FocusCard] locked \(mode.name): \(selection.applicationTokens.count) apps in \(apps.count) stores, \(selection.webDomainTokens.count) websites in \(sites.count) stores, \(selection.categoryTokens.count) categories")
    }

    static func unlock(store: SharedStore = SharedStore()) {
        stores.forEach { $0.clearAllSettings() }
        store.lockedModeName = nil
        store.lock = nil
    }

    /// Splits a list into groups of at most `perStore`.
    private static func chunks<T>(_ items: [T]) -> [[T]] {
        stride(from: 0, to: items.count, by: perStore).map { Array(items[$0..<min($0 + perStore, items.count)]) }
    }
}
