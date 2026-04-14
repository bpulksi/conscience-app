import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let screenTimeChannel = FlutterMethodChannel(
      name: "conscience/screenTime",
      binaryMessenger: controller.binaryMessenger
    )
    let avatarEventChannel = FlutterEventChannel(
      name: "conscience/avatarEvents",
      binaryMessenger: controller.binaryMessenger
    )

    screenTimeChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestPermissions":
        Task {
          do {
            try await UsageMonitor.shared.requestAuthorization()
            result(UsageMonitor.shared.isAuthorized ? "granted" : "needsSettings")
          } catch {
            result("denied")
          }
        }

      case "openPermissionSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)

      case "configureMonitoring":
        let args = call.arguments as? [String: Any]
        let dailyLimitMinutes = args?["dailyLimitMinutes"] as? Int ?? 60
        UsageMonitor.shared.startMonitoring(dailyLimitMinutes: dailyLimitMinutes)
        result(nil)

      case "grantExtension":
        let args = call.arguments as? [String: Any]
        let durationMinutes = args?["durationMinutes"] as? Int ?? 10
        UsageMonitor.shared.liftBlockForExtension(durationMinutes: durationMinutes)
        result(nil)

      case "resetBlock":
        UsageMonitor.shared.stopMonitoring()
        result(nil)

      case "consumePendingDeepLink":
        let defaults = UserDefaults(suiteName: "group.com.conscience.app")
        let deepLink = defaults?.string(forKey: "pendingDeepLink")
        defaults?.removeObject(forKey: "pendingDeepLink")
        result(deepLink)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    avatarEventChannel.setStreamHandler(AvatarEventHandler())

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// ── Avatar Stream Handler ────────────────────────────────────────────────────────

class AvatarEventHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    self.eventSink = events

    // Observe AppGroup userDefaults for avatarStage changes via Darwin notification
    observer = NotificationCenter.default.addObserver(
      forName: NSNotification.Name("com.apple.settingsupdated"),
      object: nil,
      queue: .main
    ) { _ in
      let defaults = UserDefaults(suiteName: "group.com.conscience.app")
      let stage = defaults?.string(forKey: "avatarStage") ?? "zen"
      events(stage.lowercased())
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    eventSink = nil
    return nil
  }
}
