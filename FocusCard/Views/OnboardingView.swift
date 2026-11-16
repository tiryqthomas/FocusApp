import SwiftUI

/// Welcome, then Screen Time access, then pairing a card (with Skip).
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Group {
                switch step {
                case 0:
                    page(
                        symbol: "lock.fill",
                        title: "Focus Card",
                        text: "Lock distracting apps with a tap of your card."
                    )
                case 1:
                    page(
                        symbol: "hourglass",
                        title: "Screen Time access",
                        text: "Focus Card uses Screen Time to block the apps you choose. Your data stays on this iPhone."
                    )
                default:
                    page(
                        symbol: "wave.3.right",
                        title: "Pair your card",
                        text: "Hold an NFC card or sticker near the top of the iPhone."
                    )
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
        default:
            VStack(spacing: 8) {
                Button("Pair card") {
                    Task {
                        if await model.pairCard() { model.completeOnboarding() }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Skip") { model.completeOnboarding() }
                    .frame(height: 44)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func page(symbol: String, title: String, text: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .light))
                .frame(width: 120, height: 120)
                .glassEffect(.regular, in: .circle)
            Text(title)
                .font(.largeTitle.bold())
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
