import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("haptics") private var haptics = true
    @AppStorage("appearance") private var appearance = "system"
    @State private var showCode = false

    var body: some View {
        Form {
            Section {
                NavigationLink("Bedtime, wake time and apps") { NightSetupView() }
            }
            Section {
                Stepper(value: allowance, in: 0...20) {
                    LabeledContent("Emergency unlocks a week", value: "\(model.emergencyAllowance)")
                }
            } footer: {
                Text("Refills every Monday.")
            }
            Section {
                LabeledContent("Recovery code") {
                    Text(showCode ? (model.recoveryCode ?? "None yet") : "••••-••••")
                        .font(Theme.lcdFont(17))
                }
                Button(showCode ? "Hide code" : "Show code") { showCode.toggle() }
            } footer: {
                Text("Unlocks a lost card without using an emergency unlock. Keep it somewhere safe, not on this phone only.")
            }
            Section("Look and feel") {
                Toggle("Haptics", isOn: $haptics)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                    LCDSegment(
                        options: ["system", "light", "dark"],
                        title: { $0.capitalized },
                        selection: $appearance
                    )
                }
            }
            Section {
                NavigationLink("Cards") { CardsView() }
            }
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
            }
        }
        .lcdForm()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.ensureRecoveryCode() }
    }

    private var allowance: Binding<Int> {
        Binding(get: { model.emergencyAllowance }, set: { model.setEmergencyAllowance($0) })
    }
}
