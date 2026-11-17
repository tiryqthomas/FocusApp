import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen shown when a blocked app is opened.
/// Apple draws this screen; we can only set its icon, text and colors.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    /// The same screen for every blocked app, website and category, in system
    /// colours so it follows light and dark mode. Kept quick: if this takes too
    /// long iOS shows its own grey "Restricted" screen instead.
    private func make(name: String?) -> ShieldConfiguration {
        let modeName = SharedStore().lockedModeName ?? "Focus"
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "lock.fill")?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "\(name ?? "This app") is locked", color: .label),
            subtitle: ShieldConfiguration.Label(text: "\(modeName) is on. Open Keycard and tap your card to unlock.", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .white),
            primaryButtonBackgroundColor: .systemBlue
        )
    }
}
