import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

/// Manages Screen Time authorization, app selection, and usage monitoring.
/// Call from Flutter via MethodChannel "conscience/screenTime".
@MainActor
class UsageMonitor: ObservableObject {

    static let shared = UsageMonitor()

    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.conscience.app")

    @Published var isAuthorized = false
    @Published var selection = FamilyActivitySelection()

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
            print("Screen Time authorization failed: \(error)")
        }
    }

    // MARK: - Configure Monitoring

    /// Call after user picks Vice Apps in the Flutter UI.
    /// dailyLimitMinutes: the user's chosen daily cap.
    func startMonitoring(dailyLimitMinutes: Int) {
        guard isAuthorized else { return }

        // Full-day schedule
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Warning thresholds — update avatar mood at each
        let warningEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: max(1, dailyLimitMinutes - 15))
        )
        let limitEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: dailyLimitMinutes)
        )

        do {
            try center.startMonitoring(
                .conscienceDailyActivity,
                during: schedule,
                events: [
                    .approachingLimit: warningEvent,
                    .limitReached: limitEvent
                ]
            )
        } catch {
            print("DeviceActivity monitoring error: \(error)")
        }
    }

    func stopMonitoring() {
        center.stopMonitoring([.conscienceDailyActivity])
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    // MARK: - Shield Control (called from DeviceActivityMonitor extension)

    func enforceBlock() {
        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy
            .specific(selection.categoryTokens)
        sharedDefaults?.set("FURIOUS", forKey: "avatarStage")
        sharedDefaults?.synchronize()
    }

    func liftBlockForExtension(durationMinutes: Int) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil

        // Re-engage block after grace period
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(durationMinutes * 60)) {
            self.enforceBlock()
        }
    }

    // MARK: - Update avatar stage in shared defaults (read by Shield extension)

    func updateAvatarStage(_ stage: String) {
        sharedDefaults?.set(stage, forKey: "avatarStage")
        sharedDefaults?.synchronize()
    }
}

// MARK: - DeviceActivityName constant

extension DeviceActivityName {
    static let conscienceDailyActivity = Self("conscienceDailyActivity")
}

// MARK: - DeviceActivityEvent.Name constants

extension DeviceActivityEvent.Name {
    static let approachingLimit = Self("approachingLimit")
    static let limitReached = Self("limitReached")
}
