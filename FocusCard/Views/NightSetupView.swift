import FamilyControls
import SwiftUI

/// Bedtime, wake time and blocked apps. Used in setup and in Settings.
/// Edits save as soon as they change, which also re-arms the bedtime schedule.
struct NightSetupFields: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        DatePicker("Bedtime", selection: bedtime, displayedComponents: .hourAndMinute)
        DatePicker("Wake time", selection: wake, displayedComponents: .hourAndMinute)
        Button {
            selection = model.night.selection
            picking = true
        } label: {
            LabeledContent("Lock at bedtime", value: model.night.selectionSummary)
        }
        .foregroundStyle(.primary)
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        .onChange(of: picking) { _, isOpen in
            guard !isOpen else { return }
            var night = model.night
            night.selection = selection
            model.saveNight(night)
        }
    }

    private var bedtime: Binding<Date> {
        Binding(
            get: { Self.date(hour: model.night.startHour, minute: model.night.startMinute) },
            set: { value in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
                var night = model.night
                night.startHour = parts.hour ?? 23
                night.startMinute = parts.minute ?? 0
                model.saveNight(night)
            }
        )
    }

    private var wake: Binding<Date> {
        Binding(
            get: { Self.date(hour: model.night.wakeHour, minute: model.night.wakeMinute) },
            set: { value in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
                var night = model.night
                night.wakeHour = parts.hour ?? 7
                night.wakeMinute = parts.minute ?? 0
                model.saveNight(night)
            }
        )
    }

    private static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }
}

/// Settings screen for the night routine.
struct NightSetupView: View {
    var body: some View {
        Form {
            Section {
                NightSetupFields()
            } footer: {
                Text("Phone, Messages and Clock stay open. Pick Social and Entertainment categories, plus any websites, in the app list.")
            }
        }
        .lcdForm()
        .navigationTitle("Your night")
        .navigationBarTitleDisplayMode(.inline)
    }
}
