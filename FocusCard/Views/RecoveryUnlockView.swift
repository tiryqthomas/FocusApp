import SwiftUI

/// For a lost card or a scan that won't work. Doesn't use an emergency unlock.
struct RecoveryUnlockView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var wrong = false

    var body: some View {
        Form {
            if model.hasRecoveryCode {
                Section {
                    TextField("FC-XXXX-XXXX", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                } footer: {
                    Text(wrong ? "That code isn't right." : "Enter the recovery code you saved when you made it.")
                        .foregroundStyle(wrong ? .red : .secondary)
                }
                Section {
                    Button("Unlock") {
                        if model.unlockWithRecoveryCode(code) {
                            dismiss()
                        } else {
                            wrong = true
                        }
                    }
                    .disabled(code.isEmpty)
                }
            } else {
                Text("No recovery code was made. Make one in Settings next time you're unlocked.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Recovery code")
        .navigationBarTitleDisplayMode(.inline)
    }
}
