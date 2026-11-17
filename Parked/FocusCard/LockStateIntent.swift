import AppIntents

/// "Is Keycard Locked?" for the minimal Home Screen automation (Decision 15c).
struct IsLockedIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Keycard Locked?"
    static let description = IntentDescription("Returns true while a Keycard mode is locked.")

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: SharedStore().lock != nil)
    }
}

struct FocusCardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: IsLockedIntent(),
            phrases: ["Is \(.applicationName) locked"],
            shortTitle: "Is Locked?",
            systemImageName: "lock"
        )
    }
}
