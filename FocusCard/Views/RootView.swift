import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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
