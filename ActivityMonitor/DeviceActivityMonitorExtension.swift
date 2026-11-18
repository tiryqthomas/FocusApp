import DeviceActivity
import Foundation

/// Starts the night lock at bedtime. Ending it still needs a card after wake time.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let store = SharedStore()
        // If something is already locked, leave it.
        guard store.lock == nil, activity == FocusSchedule.activity else { return }
        let night = store.night
        guard night.scheduleEnabled, !night.isEmpty else { return }
        FocusEngine.lock(night, night: true, store: store)
    }
}
