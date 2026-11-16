import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if !model.onboarded {
                OnboardingView()
            } else if model.lock != nil {
                LockedView()
                    .transition(.opacity)
            } else {
                NavigationStack { HomeView() }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: model.lock)
        .sensoryFeedback(.success, trigger: model.lock)
        .alert("Focus Card", isPresented: alertShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private var alertShown: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )
    }
}

/// The black full-width capsule used for the main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary.opacity(isEnabled ? 1 : 0.3), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.3), value: configuration.isPressed)
    }
}
