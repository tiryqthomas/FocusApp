import AlarmKit
import SwiftUI

struct SleepKeyAlarmMetadata: AlarmMetadata {}

/// SleepKey's own daily wake alarm, made with AlarmKit (iOS 26). It rings like a
/// system alarm, even on silent or in a Focus. Apple gives apps no access to the
/// alarms in the Clock app, so this is a separate alarm.
enum WakeAlarm {
    private static let id = UUID(uuidString: "8E1F3C52-6B1A-4D0E-9A57-0C2B7D4E5F10")!

    /// Schedules the alarm for the night's wake time, or removes it when it is off.
    static func sync(_ night: FocusMode) async {
        try? AlarmManager.shared.cancel(id: id)
        guard night.wakeAlarmOn else { return }
        guard await authorized() else { return }

        let time = Alarm.Schedule.Relative.Time(hour: night.wakeHour, minute: night.wakeMinute)
        let everyDay: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: .weekly(everyDay)))
        let alert = AlarmPresentation.Alert(
            title: "Good morning",
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: SleepKeyAlarmMetadata(),
            tintColor: .blue
        )
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: schedule,
            attributes: attributes
        )
        _ = try? await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }

    private static func authorized() async -> Bool {
        switch AlarmManager.shared.authorizationState {
        case .authorized: return true
        case .notDetermined: return (try? await AlarmManager.shared.requestAuthorization()) == .authorized
        default: return false
        }
    }
}
