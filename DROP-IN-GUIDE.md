# Conscience Phase 2 — Drop-in Guide

After exporting your Stitch project, follow these steps to integrate the native layer.

---

## 1. Firebase Cloud Functions

```bash
cd conscience-phase2/functions
npm install
npm run build
firebase deploy --only functions
```

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
  uuid: ^4.4.0
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

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
      // Partner can read limited fields
      allow read: if request.auth.uid in resource.data.keys(); // tighten as needed
    }

    match /usageStats/{uid}/{document=**} {
      allow read, write: if request.auth.uid == uid;
    }

    match /extensionRequests/{reqId} {
      allow read: if request.auth.uid == resource.data.requesterId
                  || request.auth.uid == resource.data.partnerId;
      allow create: if request.auth.uid == request.resource.data.requesterId;
      allow update: if request.auth.uid == resource.data.partnerId
                    && request.resource.data.status in ['approved', 'denied'];
    }

    match /wellnessTokens/{token} {
      allow create: if request.auth.uid == request.resource.data.uid;
      allow read: if request.auth.uid == resource.data.uid;
      // Updates only via Cloud Function (admin SDK bypasses rules)
    }

    match /inviteCodes/{code} {
      allow create: if request.auth != null;
      allow read: if request.auth != null;
    }
  }
}
```
