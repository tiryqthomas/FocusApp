import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("haptics") private var haptics = true
    @AppStorage("appearance") private var appearance = "system"
    @State private var showCode = false

    var body: some View {
        Form {
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
                NavigationLink("Set up Home Screen") { MinimalSetupView() }
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

/// Decision 15c: a minimal Home Screen through an iOS Focus and a Shortcuts automation.
/// Apple doesn't let apps change the Home Screen, so this is set up once by hand.
struct MinimalSetupView: View {
    var body: some View {
        List {
            Section {
                Text("When Focus Card locks, your iPhone can switch to a near-empty Home Screen in grayscale. Set it up once in iOS.")
                    .foregroundStyle(.secondary)
            }
            Section("1. Make a minimal Home Screen") {
                step("Long-press the Home Screen, then tap Edit and Add Page.")
                step("Add only the apps you want while locked, such as Phone, Messages, Maps and Camera.")
            }
            Section("2. Create a Focus") {
                step("Open Settings, then Focus, then +, then Custom. Name it Focus Card.")
                step("Under Customize Screens, choose the Home Screen page you just made.")
            }
            Section("3. Add the automation") {
                step("Open Shortcuts, then Automation, then +, then App. Choose Focus Card and Is Closed.")
                step("Choose Run Immediately.")
                step("Add the action Is Focus Card Locked.")
                step("Add If: if the result is true, add Set Focus Card On and Set Color Filters On. Otherwise, add Set Focus Card Off and Set Color Filters Off.")
            }
            Section {
                Link(destination: URL(string: "shortcuts://")!) {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                }
            }
        }
        .lcdForm()
        .navigationTitle("Set up Home Screen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ text: String) -> some View {
        Text(text)
    }
}
