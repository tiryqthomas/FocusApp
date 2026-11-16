import AppIntents

/// "Is Focus Card Locked?" for the minimal Home Screen automation (Decision 15c).
struct IsLockedIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Focus Card Locked?"
    static let description = IntentDescription("Returns true while a Focus Card mode is locked.")

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
