import SwiftUI
import UIKit

/// Welcome, Screen Time access, pairing a card (with Skip), then the recovery code.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var copied = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Group {
                switch step {
                case 0:
                    page(
                        symbol: "lock.fill",
                        title: "Keycard",
                        text: "Lock distracting apps with a tap of your card."
                    )
                case 1:
                    page(
                        symbol: "hourglass",
                        title: "Screen Time access",
                        text: "Keycard uses Screen Time to block the apps you choose. Your data stays on this iPhone."
                    )
                case 2:
                    page(
                        symbol: "wave.3.right",
                        title: "Pair your card",
                        text: "Hold an NFC card or sticker near the top of the iPhone."
                    )
                default:
                    VStack(spacing: 18) {
                        icon("key.fill")
                        Text("Recovery code")
                            .font(.largeTitle.bold())
                        Text(model.recoveryCode ?? "")
                            .font(Theme.lcdFont(30))
                            .tracking(2)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .lcdPanel()
                        Text("If you lose your card, this code unlocks your phone without using an emergency unlock. Save it somewhere that is not this phone.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            Spacer()
            actions
        }
        .padding(20)
        .animation(.spring(duration: 0.45), value: step)
        .lcdScreen()
    }

    @ViewBuilder
    private var actions: some View {
        switch step {
        case 0:
            Button("Continue") { step = 1 }
                .buttonStyle(PrimaryButtonStyle())
        case 1:
            Button("Allow") {
                Task {
                    await model.requestAuthorization()
                    if model.isAuthorized { step = 2 }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        case 2:
            VStack(spacing: 8) {
                Button("Pair card") {
                    Task {
                        if await model.pairCard() { goToRecovery() }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Skip") { goToRecovery() }
                    .frame(height: 44)
                    .foregroundStyle(.secondary)
            }
        default:
            VStack(spacing: 8) {
                Button(copied ? "Copied" : "Copy code") {
                    UIPasteboard.general.string = model.recoveryCode
                    copied = true
                }
                .buttonStyle(SecondaryButtonStyle())
                Button("Done") { model.completeOnboarding() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func goToRecovery() {
        model.ensureRecoveryCode()
        step = 3
    }

    private func icon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 44, weight: .light))
            .frame(width: 120, height: 120)
            .lcdPanel()
    }

    private func page(symbol: String, title: String, text: String) -> some View {
        VStack(spacing: 18) {
            icon(symbol)
            Text(title)
                .font(.largeTitle.bold())
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
