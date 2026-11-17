import UIKit
import SwiftUI

/// Only reachable while unlocked, so it can't be used to get out of a lock.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showCode = false
    @State private var showSave = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Cards") {
                    LabeledContent("Card", value: model.card == nil ? "Not paired" : "Paired")
                    Button(model.card == nil ? "Pair a Card" : "Pair a New Card") {
                        Task { await model.pairCard() }
                    }
                }

                Section {
                    Stepper(value: Binding(
                        get: { model.emergency.perWeek },
                        set: { model.setEmergencyPerWeek($0) }
                    ), in: 0...10) {
                        LabeledContent("Unlocks a week", value: "\(model.emergency.perWeek)")
                    }
                    LabeledContent("Recovery password") {
                        Text(showCode ? model.recoveryCode : "FC-••••-••••")
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                    Button(showCode ? "Hide Password" : "Show Password") { showCode.toggle() }
                    if model.recoveryCodeSaved {
                        Label("Saved to Passwords", systemImage: "checkmark")
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Save to Passwords") { showSave = true }
                    }
                } header: {
                    Text("Emergency")
                } footer: {
                    Text("\(model.emergency.remaining) emergency unlocks left this week. They reset every Monday.")
                }

                Section("App") {
                    Picker("Appearance", selection: Binding(
                        get: { model.appearance },
                        set: { model.setAppearance($0) }
                    )) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Haptics", isOn: Binding(
                        get: { model.hapticsOn },
                        set: { model.setHaptics($0) }
                    ))
                    .tint(Theme.focus)
                    if model.isAuthorized {
                        LabeledContent("Screen Time access", value: "Allowed")
                    } else {
                        Button("Allow Screen Time Access") {
                            Task { await model.requestAuthorization() }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showSave) {
                SaveRecoveryView()
            }
        }
    }
}

/// Asks the user to keep the recovery password in Apple's Passwords app.
///
/// iOS only shows its own "Save Password?" sheet for apps linked to a website
/// (webcredentials). Keycard has none, so this copies the password and
/// opens Passwords, where it's pasted into a new entry.
struct SaveRecoveryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    var body: some View {
        VStack(spacing: HomeView.spacing) {
            Image(systemName: "key.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color(.systemGray), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 8)
            Text("Save Recovery Password?")
                .font(.title3.weight(.semibold))
            Text(copied
                 ? "Copied. In Passwords, tap +, name it Keycard, and paste the password."
                 : "Save it to Passwords so you can unlock if your card is lost or will not scan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(model.recoveryCode)
                .font(.title3.monospaced().weight(.semibold))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 0)
            if copied {
                Button {
                    model.markRecoveryCodeSaved()
                    dismiss()
                } label: {
                    Text("Done, It's Saved")
                }
                .buttonStyle(CapsuleButtonStyle(fill: .primary, text: Color(.systemBackground)))
            } else {
                Button {
                    UIPasteboard.general.string = model.recoveryCode
                    copied = true
                    if let url = URL(string: "passwords://") { openURL(url) }
                } label: {
                    Text("Save to Passwords")
                }
                .buttonStyle(CapsuleButtonStyle(fill: .primary, text: Color(.systemBackground)))
            }
            Button("Not Now") { dismiss() }
                .padding(.bottom, 4)
        }
        .padding(24)
        .presentationDetents([.medium])
        .haptic(.success, enabled: model.hapticsOn, trigger: copied)
    }
}
