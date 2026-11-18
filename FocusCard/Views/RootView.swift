import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    /// "system" follows the iPhone's light or dark setting. Settings can force one.
    @AppStorage("appearance") private var appearance = "system"

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
        .haptic(.success, trigger: model.lock)
        .preferredColorScheme(preferredScheme)
        .tint(Theme.blue)
        .alert("SleepKey", isPresented: alertShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var alertShown: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )
    }
}
