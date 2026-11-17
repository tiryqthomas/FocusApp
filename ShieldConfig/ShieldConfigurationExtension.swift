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

    private func make(name: String?) -> ShieldConfiguration {
        let modeName = SharedStore().lock?.modeName ?? "Focus"
        return ShieldConfiguration(
            backgroundColor: .black,
            icon: UIImage(systemName: "lock.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "\(name ?? "This app") is locked", color: .white),
            subtitle: ShieldConfiguration.Label(text: "\(modeName) is on. Scan your card in Focus Card to unlock.", color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .black),
            primaryButtonBackgroundColor: .white
        )
    }
}
