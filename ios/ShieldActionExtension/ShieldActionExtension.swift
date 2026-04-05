import ManagedSettings
import UIKit

/// Handles button taps on the Shield block screen.
/// Cannot open URLs directly — writes intent to shared App Group,
/// main app observes via NotificationCenter / scenePhase.
class ShieldActionExtension: ShieldActionDelegate {

    private let sharedDefaults = UserDefaults(suiteName: "group.com.conscience.app")

    override func handle(
        action: ShieldAction,
        for application: Application,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for applicationCategory: ActivityCategory,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        handleAction(action: action, completionHandler: completionHandler)
    }

    private func handleAction(
        action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            // Signal main app to navigate to Recharge Hub
            sharedDefaults?.set("rechargeHub", forKey: "pendingDeepLink")
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "pendingDeepLinkTimestamp")
            sharedDefaults?.synchronize()
            completionHandler(.defer) // keep shield up, app handles navigation

        case .secondaryButtonPressed:
            // Signal main app to trigger Ask a Friend flow
            sharedDefaults?.set("askFriend", forKey: "pendingDeepLink")
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "pendingDeepLinkTimestamp")
            sharedDefaults?.synchronize()
            completionHandler(.defer)

        @unknown default:
            completionHandler(.close)
        }
    }
}
