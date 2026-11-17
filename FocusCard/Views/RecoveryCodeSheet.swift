import SwiftUI
import UIKit

/// Shows a new recovery code once.
struct RecoveryCodeSheet: View {
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
                Text("Tap Copy, then add it in the Passwords app (tap +, name it Focus Card). You won't see it again.")
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
