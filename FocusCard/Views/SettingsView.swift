import SwiftUI

/// Only reachable while unlocked.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                Stepper(value: allowance, in: 0...20) {
                    LabeledContent("Emergency unlocks a week", value: "\(model.emergencyAllowance)")
                }
            } footer: {
                Text("\(model.emergencyLeft) left this week. They refill every Monday.")
            }

            Section {
                LabeledContent("Recovery code", value: model.hasRecoveryCode ? "Made" : "Not made yet")
            } footer: {
                Text("Made once, when you pair your card, and shown only then. It unlocks without your card if it's lost or the scan won't work.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var allowance: Binding<Int> {
        Binding(get: { model.emergencyAllowance }, set: { model.setEmergencyAllowance($0) })
    }
}
