import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Shield UI shown when a Vice App is blocked by Screen Time.
/// This runs in a sandboxed extension process — no network, no Firebase.
/// Reads avatar state from shared App Group UserDefaults written by the main app.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.conscience.app")

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        return buildConfiguration()
    }

    override func configuration(
        shielding applicationCategory: ActivityCategory
    ) -> ShieldConfiguration {
        return buildConfiguration()
    }

    private func buildConfiguration() -> ShieldConfiguration {
        let stage = sharedDefaults?.string(forKey: "avatarStage") ?? "FURIOUS"
        let isToughLove = sharedDefaults?.bool(forKey: "toughLove") ?? true

        let bgColor: UIColor = stage == "FURIOUS"
            ? UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.92)
            : UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.92)

        let title = isToughLove
            ? "Your Conscience has had enough."
            : "Hey, you've hit your limit."

        let subtitle = isToughLove
            ? "You've used up your screen time. Close the app."
            : "How about a short recharge break?"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: bgColor,
            icon: UIImage(named: "avatar_\(stage.lowercased())") ?? UIImage(systemName: "brain.head.profile"),
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor.white.withAlphaComponent(0.85)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Recharge Hub",
                color: UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1)
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.66, green: 0.85, blue: 0.92, alpha: 1), // #A8D8EA
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Ask a Friend for 10 mins",
                color: .white
            )
        )
    }
}
