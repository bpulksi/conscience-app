# Conscience Phase 2 — Drop-in Guide

After exporting your Stitch project, follow these steps to integrate the native layer.

---

## 1. Firebase Cloud Functions

Run these from the repo root. They need Node 22, the Firebase CLI, and a Firebase project with Auth, Firestore and Cloud Messaging enabled. Cloud Functions also requires the Blaze plan.

```bash
firebase use --add
npm --prefix functions install
npm --prefix functions test
firebase deploy --only firestore,functions
```

This deploys the functions, `firestore.rules` and `firestore.indexes.json`. A new composite index can take a few minutes to build, and `requestExtension` fails until it's ready.

The app must save each device's push token to `users/{uid}.fcmToken` using `firebase_messaging`, or partners won't get notifications.

---

## 2. Flutter Services

Copy these into your exported Flutter project:

```
conscience-phase2/flutter/lib/services/  →  lib/services/
```

Add to `pubspec.yaml`:
```yaml
dependencies:
  cloud_functions: ^4.7.0
  cloud_firestore: ^4.17.0
  firebase_auth: ^4.20.0
```

---

## 3. Android

### Copy source files
```
conscience-phase2/android/app/src/main/java/com/conscience/app/
  → android/app/src/main/java/com/YOUR_PACKAGE/
```
Update the `package` declaration in each file to match your package name.

### Copy resources
```
conscience-phase2/android/app/src/main/res/layout/overlay_avatar.xml   → android/app/src/main/res/layout/
conscience-phase2/android/app/src/main/res/layout/activity_block.xml   → android/app/src/main/res/layout/
conscience-phase2/android/app/src/main/res/xml/accessibility_service_config.xml → android/app/src/main/res/xml/
```

### Update AndroidManifest.xml
Merge the contents of `manifest_additions.xml` into `android/app/src/main/AndroidManifest.xml`.

### Add to build.gradle (app level)
```groovy
dependencies {
    implementation 'com.airbnb.android:lottie:6.4.0'
    implementation 'com.google.firebase:firebase-firestore-ktx:25.0.0'
    implementation 'com.google.firebase:firebase-auth-ktx:23.0.0'
}
```

### Add Lottie animation files
```
assets/avatars/brain/zen.json
assets/avatars/brain/impatient.json
assets/avatars/brain/furious.json
```
Source free Lottie animations from lottiefiles.com or commission custom ones.

---

## 4. iOS

### Xcode setup (required — cannot be done via Flutter CLI)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Add **App Group** capability to Runner target: `group.com.conscience.app`
3. Add **Screen Time** capability (requires Apple approval for production)
4. Add **Family Controls** capability

### Add two new Targets in Xcode

**Target 1: ShieldConfigurationExtension**
- File > New > Target > Shield Configuration Extension
- Replace generated Swift file with `ios/ShieldConfigurationExtension/ShieldConfigurationExtension.swift`
- Add App Group `group.com.conscience.app` to this target

**Target 2: ShieldActionExtension**
- File > New > Target > Shield Action Extension
- Replace generated Swift file with `ios/ShieldActionExtension/ShieldActionExtension.swift`
- Add App Group `group.com.conscience.app` to this target

**Target 3: DeviceActivityMonitorExtension**
- File > New > Target > Device Activity Monitor Extension
- Replace generated Swift file with `ios/Runner/DeviceActivityMonitorExtension.swift`
- Add App Group `group.com.conscience.app` to this target

### Add UsageMonitor to Runner target
- Drag `ios/Runner/UsageMonitor.swift` into the Runner target in Xcode
- Add App Group `group.com.conscience.app` to Runner target

---

## 5. Connect Flutter ↔ Native (MethodChannel)

In `android/app/src/main/java/com/YOUR_PACKAGE/MainActivity.kt`, register the channel:

```kotlin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "conscience/screenTime")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermissions" -> handleRequestPermissions(result)
                    "configureMonitoring" -> handleConfigureMonitoring(call.arguments as Map<*, *>, result)
                    "grantExtension" -> handleGrantExtension(result)
                    "resetBlock" -> handleResetBlock(result)
                    else -> result.notImplemented()
                }
            }
    }
    // ... implement each handler
}
```

For iOS, add the equivalent `FlutterMethodChannel` setup in `AppDelegate.swift`.

---

## 6. Onboarding Permission Request

In your Flutter onboarding flow, call:

```dart
final bridge = NativeBridge();
final status = await bridge.requestPermissions();

if (status == PermissionStatus.needsSettings) {
  // Show explanation dialog, then:
  await bridge.openPermissionSettings();
}
```

---

## Firestore Security Rules

The rules are in [`firestore.rules`](firestore.rules) and deploy with the functions. Coins, partner links, wellness sessions and approvals can only be changed through Cloud Functions.

To test the rules and backend on the Firestore emulator (needs Java 21 or newer):

```bash
npm --prefix functions install
npm --prefix rules-tests install
npm --prefix rules-tests test
```

If the emulator fails on Windows with `Unable to establish loopback connection`, your temp folder path is probably the cause. Create a plain folder such as `C:\jtmp` and set `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\jtmp` before running the tests.
