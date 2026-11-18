import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The black screen shown when a blocked app is opened (canvas screen 5).
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
        let isNight = SharedStore().lock?.night == true
        let glow = UIColor(red: 0x9E / 255, green: 0xC1 / 255, blue: 0xFF / 255, alpha: 1)
        return ShieldConfiguration(
            backgroundColor: .black,
            icon: UIImage(systemName: "lock.fill")?.withTintColor(glow, renderingMode: .alwaysOriginal),
            title: ShieldConfiguration.Label(text: "\(name ?? "This app") is locked", color: glow),
            subtitle: ShieldConfiguration.Label(text: isNight ? "Locked for the night. Tap your card in the app after wake time." : "Locked. Tap your card in the app to unlock.", color: glow.withAlphaComponent(0.8)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: .black),
            primaryButtonBackgroundColor: glow
        )
    }
}
