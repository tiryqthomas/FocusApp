import DeviceActivity
import Foundation

/// Starts a scheduled mode (Decision 6). Ending it still needs a card.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let store = SharedStore()
        // Decision 7: one mode at a time. If something is already locked, leave it.
        guard store.lock == nil,
              let id = FocusSchedule.modeID(from: activity),
              let mode = store.modes.first(where: { $0.id == id }),
              !mode.isEmpty
        else { return }
        FocusEngine.lock(mode, store: store)
    }
}
