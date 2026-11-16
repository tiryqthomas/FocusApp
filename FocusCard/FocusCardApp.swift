import SwiftUI

@main
struct FocusCardApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onChange(of: scenePhase) { _, phase in
                    // A scheduled mode may have locked while the app was closed.
                    if phase == .active { model.reload() }
                }
        }
    }
}
