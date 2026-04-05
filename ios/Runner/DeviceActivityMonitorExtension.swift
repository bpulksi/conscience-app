import DeviceActivity
import ManagedSettings

/// This extension is called by the OS when usage thresholds are crossed.
/// Runs out-of-process — no Firebase, no main app context.
/// Writes to shared App Group to signal the main app.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.conscience.app")

    override func intervalDidStart(for activity: DeviceActivityName) {
        // New day — reset stage to ZEN
        sharedDefaults?.set("ZEN", forKey: "avatarStage")
        sharedDefaults?.synchronize()
        store.shield.applications = nil
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        switch event {
        case .approachingLimit:
            // Update avatar to IMPATIENT — main app picks this up via AppGroup polling
            sharedDefaults?.set("IMPATIENT", forKey: "avatarStage")
            sharedDefaults?.synchronize()

        case .limitReached:
            // Block apps + set FURIOUS avatar
            sharedDefaults?.set("FURIOUS", forKey: "avatarStage")
            sharedDefaults?.synchronize()

            // Apply shield — tokens were saved to App Group by main app at setup
            if let data = sharedDefaults?.data(forKey: "applicationTokens"),
               let tokens = try? NSKeyedUnarchiver.unarchivedObject(
                   ofClass: NSSet.self, from: data
               ) as? Set<Application> {
                store.shield.applications = tokens
            }

        default:
            break
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // End of day — lift all blocks
        store.shield.applications = nil
        sharedDefaults?.set("ZEN", forKey: "avatarStage")
        sharedDefaults?.synchronize()
    }
}
