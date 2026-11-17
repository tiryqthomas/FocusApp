import SwiftUI

@main
struct FocusCardApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // Tapping the card outside the app: iOS reads its focuscard:// link,
                // shows a notification, and opening it lands here.
                .onOpenURL { url in
                    Task { await model.handleCardLink(url) }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.reload() }
                }
        }
    }
}
