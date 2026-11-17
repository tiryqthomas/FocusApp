import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.lock != nil {
                LockedView()
                    .transition(.opacity)
            } else {
                NavigationStack { HomeView() }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.lock)
        .sensoryFeedback(.success, trigger: model.lock)
        .preferredColorScheme(colorScheme)
        .task { model.offerRecoverySaveIfNeeded() }
        .sheet(isPresented: $model.showSaveRecovery) {
            SaveRecoveryView()
        }
        .alert("Focus Card", isPresented: alertShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private var colorScheme: ColorScheme? {
        switch model.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var alertShown: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )
    }
}
