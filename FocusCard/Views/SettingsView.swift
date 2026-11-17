import SwiftUI
import UIKit

/// Only reachable while unlocked.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var newCode: String?
    @State private var confirmReplace = false

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
                Button(model.hasRecoveryCode ? "Make a new recovery code" : "Make a recovery code") {
                    if model.hasRecoveryCode { confirmReplace = true } else { newCode = model.makeRecoveryCode() }
                }
            } footer: {
                Text("Unlocks without your card if it's lost or the scan won't work. The code is shown once, so save it somewhere other than this phone.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Replace your recovery code?", isPresented: $confirmReplace, titleVisibility: .visible) {
            Button("Make new code", role: .destructive) { newCode = model.makeRecoveryCode() }
        } message: {
            Text("The old code will stop working.")
        }
        .sheet(item: codeBinding) { item in
            RecoveryCodeSheet(code: item.code)
        }
    }

    private var allowance: Binding<Int> {
        Binding(get: { model.emergencyAllowance }, set: { model.setEmergencyAllowance($0) })
    }

    private var codeBinding: Binding<CodeItem?> {
        Binding(get: { newCode.map(CodeItem.init) }, set: { newCode = $0?.code })
    }
}

private struct CodeItem: Identifiable {
    let code: String
    var id: String { code }
}

/// Shows a new recovery code once.
private struct RecoveryCodeSheet: View {
    let code: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "key.fill")
                    .font(.system(size: 44))
                Text(code)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)
                Text("Write this down or save it somewhere other than this phone. You won't see it again.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(copied ? "Copied" : "Copy code") {
                    UIPasteboard.general.string = code
                    copied = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Recovery code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("I saved it") { dismiss() }
                }
            }
            .interactiveDismissDisabled()
        }
    }
}
