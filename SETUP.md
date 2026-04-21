# Conscience App — Local Setup Guide

This repository is now a fully scaffolded Flutter app with native Android and iOS integration for Screen Time / Family Controls monitoring. The code is ready to run, but **several manual steps** are required because they cannot be automated via Xcode or CLI.

---

## 1. Flutter + Firebase Setup

### 1.1 Install dependencies and configure Firebase

```bash
cd flutter
flutter pub get
flutterfire configure --project=conscience-62d8b
```

This command:
- Interactively signs you in to Firebase
- Generates `lib/firebase_options.dart` with real credentials
- Downloads `google-services.json` (Android)
- Downloads `GoogleService-Info.plist` (iOS)

### 1.2 Install Firebase CLI

If you haven't already:

```bash
npm install -g firebase-tools
firebase login
```

### 1.3 Deploy Cloud Functions

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### 1.4 Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

---

## 2. Android Setup

### 2.1 Generate gradle wrapper (if missing)

```bash
cd android
gradle wrapper --gradle-version 8.4
cd ..
```

### 2.2 Accept Android SDK licenses

```bash
flutter doctor --android-licenses
```

### 2.3 Run on Android device/emulator

```bash
flutter run -d <device-id>
# or
flutter run  # picks default device
```

After the app launches:
1. **Permissions screen**: Tap "Continue" → accept Accessibility Service in system settings
2. **Partner screen**: (Optional) generate or enter an invite code
3. **Home screen**: Configure vice apps, set daily limit, start monitoring

---

## 3. iOS Setup — **Manual Xcode steps required**

### 3.1 Install pods

```bash
cd ios
pod install --repo-update
cd ..
```

### 3.2 Open Xcode workspace

**Important:** Always use `.xcworkspace`, not `.xcodeproj`:

```bash
open ios/Runner.xcworkspace
```

### 3.3 Create three new extension targets

In Xcode, go to **File → New → Target** and create these **in this order**:

#### Target 1: ShieldConfigurationExtension

1. Choose **Shield Configuration Extension** template
2. Name: `ShieldConfigurationExtension`
3. Language: Swift
4. Team & bundle ID: match the main Runner target
5. **After creation:**
   - Delete the generated `ShieldConfigurationExtension.swift`
   - Drag `/ios/ShieldConfigurationExtension/ShieldConfigurationExtension.swift` from Finder into the target
   - Set deployment target to iOS 16.0

#### Target 2: ShieldActionExtension

1. Choose **Shield Action Extension** template
2. Name: `ShieldActionExtension`
3. Language: Swift
4. Team & bundle ID: match the main Runner target
5. **After creation:**
   - Delete the generated `ShieldActionExtension.swift`
   - Drag `/ios/ShieldActionExtension/ShieldActionExtension.swift` from Finder into the target
   - Set deployment target to iOS 16.0

#### Target 3: DeviceActivityMonitorExtension

1. Choose **Device Activity Monitor Extension** template
2. Name: `DeviceActivityMonitorExtension`
3. Language: Swift
4. Team & bundle ID: match the main Runner target
5. **After creation:**
   - Delete the generated `DeviceActivityMonitorExtension.swift`
   - Drag `/ios/Runner/DeviceActivityMonitorExtension.swift` from Finder into the target
   - Set deployment target to iOS 16.0

### 3.4 Add App Group capability to all 4 targets

For each target (Runner, ShieldConfigurationExtension, ShieldActionExtension, DeviceActivityMonitorExtension):

1. Select the target in Xcode
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Set the group to: `group.com.conscience.app`

### 3.5 Add Family Controls capability to Runner only

1. Select the **Runner** target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Family Controls**

### 3.6 Request entitlements from Apple (production only)

To distribute on App Store, you must request the Family Controls distribution entitlement:

1. Go to [Apple Developer](https://developer.apple.com/)
2. Certificates, Identifiers & Profiles → App IDs
3. Select your app ID
4. Enable **Family Controls** capability
5. Save and submit for approval

This requires:
- Clear explanation of how you monitor device usage
- Privacy policy covering parental control data
- Demo account credentials for testing
- Usually takes 1–3 business days

For testing on your own device, you can proceed without this approval.

### 3.7 Add UsageMonitor to Runner target (if not already present)

If `/ios/Runner/UsageMonitor.swift` is not showing in the Runner target's "Build Phases → Compile Sources":

1. In Xcode, select `UsageMonitor.swift`
2. In the **File Inspector** (right panel), check the **Target Membership** box for Runner

### 3.8 Build and run

```bash
flutter run -d <device-id>
# or
flutter run  # picks default device
```

**Note:** iOS requires a physical device or the following workarounds:
- Use a simulator, but Screen Time API is not fully functional (Family Controls unavailable)
- Alternatively, run on a physical iOS 16+ device

---

## 4. Avatar Art (Lottie animations)

The app currently uses **placeholder** Lottie JSON files:
- `flutter/assets/avatars/brain/zen.json` (teal circle)
- `flutter/assets/avatars/brain/impatient.json` (amber circle)
- `flutter/assets/avatars/brain/furious.json` (red circle)

To replace with real animations:

1. Download or design 3 Lottie animations from [lottiefiles.com](https://lottiefiles.com)
   - One calm/zen state
   - One warning/impatient state
   - One blocked/furious state

2. Replace the JSON files:
   - `flutter/assets/avatars/brain/zen.json`
   - `flutter/assets/avatars/brain/impatient.json`
   - `flutter/assets/avatars/brain/furious.json`

3. **Also** update the Android copies:
   - `android/app/src/main/assets/avatars/brain/zen.json`
   - `android/app/src/main/assets/avatars/brain/impatient.json`
   - `android/app/src/main/assets/avatars/brain/furious.json`

---

## 5. Emulator Testing (optional)

To test Cloud Functions and Firestore without deploying to the cloud:

```bash
firebase emulators:start
```

Then run with:

```bash
flutter run --dart-define=USE_EMULATOR=true
```

---

## 6. Troubleshooting

### Android

- **"Accessibility Service not found"** → Open Android Settings → Accessibility → check Conscience is enabled
- **"Can't draw overlays"** → Open Settings → Apps → Conscience → Advanced → Allow Display over other apps
- **Gradle sync fails** → Run `flutter clean && flutter pub get && flutter build apk`

### iOS

- **"Screen Time API not available"** → Requires iOS 16+; simulators may not support all Family Controls features
- **Missing frameworks** → Run `cd ios && pod install --repo-update`
- **Build fails with "bitcode"** → Ensure all pods have Bitcode disabled (usually automatic)

### Firebase

- **Cloud Functions not reachable** → Ensure `firebase deploy --only functions` succeeded
- **Firestore rules error** → Check `.firebaserc` has correct project ID

---

## 7. Architecture Overview

### Flutter
- **Services**: `native_bridge.dart`, `partner_service.dart`, `wellness_service.dart` handle MethodChannel calls and Firestore read/writes
- **Screens**: Onboarding (permissions, partner linking) and Home (today, recharge, partners tabs)
- **Theme**: Dark Material 3 design

### Android
- **MainActivity**: Registers MethodChannel and broadcasts avatar stage updates
- **ConscienceAccessibilityService**: Monitors foreground app, accumulates usage, triggers hard block
- **OverlayManager**: Renders draggable Lottie avatar
- **BlockActivity**: Full-screen block shown when daily limit is reached
- **LocalBroadcastManager**: Inter-process communication between MainActivity and service

### iOS
- **AppDelegate**: Registers MethodChannel for native calls
- **UsageMonitor**: Manages Screen Time authorization, monitoring, and shield enforcement
- **DeviceActivityMonitorExtension**: Monitors device activity threshold events
- **ShieldConfigurationExtension**: Builds Shield UI
- **ShieldActionExtension**: Handles Shield button taps
- **App Group shared defaults**: Communication between extensions and main app

### Firebase
- **Cloud Functions**: `claimWellnessReward`, `linkAccountabilityPartner`, `unlinkAccountabilityPartner`, `requestExtension`
- **Firestore collections**: `users`, `usageStats`, `inviteCodes`, `extensionRequests`, `wellnessTokens`
- **Security rules**: UID-based access control with partner read access

---

## 8. Next Steps

After setup:

1. Test onboarding → grant permissions
2. Configure vice apps and daily limit
3. Open a monitored app → overlay appears
4. Test partner linking via invite codes
5. Test wellness sessions (breathwork/meditation/yoga)
6. Test extension requests (if two devices are set up)

---

## FAQ

**Q: Can I use anonymous auth in production?**  
A: No. For production, add email/Apple sign-in flow. The scaffold uses anonymous for simplicity; replace `signInAnonymously()` in `main.dart` with `signInWithApple()` or similar.

**Q: How do I customize the mood thresholds?**  
A: Edit the ratios in `ConscienceAccessibilityService.resolveStage()` (Android) and thresholds in `UsageMonitor.startMonitoring()` (iOS).

**Q: Can I deploy to TestFlight?**  
A: Yes, after requesting the Family Controls entitlement from Apple. Build with `flutter build ios --release` and use Xcode to upload to App Store Connect.

**Q: What's the privacy stance?**  
A: All usage data stays on-device until the user explicitly claims a wellness reward or shares an extension request with their partner. No telemetry is collected.

---

**Scaffolding completed on Apr 14, 2026 with Firebase project `conscience-62d8b`.**
