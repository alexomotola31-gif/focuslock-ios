import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen people see when they open a locked app.
class FocusLockShield: ShieldConfigurationDataSource {

    private func make() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.07, blue: 0.16, alpha: 0.92),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(text: "Locked by FocusLock", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "Lock in. Stay focused. This is locked until your session ends.",
                color: UIColor(red: 0.73, green: 0.71, blue: 0.96, alpha: 1))
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { make() }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make() }
}
