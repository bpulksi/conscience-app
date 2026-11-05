// Placeholder so the project analyzes locally. CI replaces this file at build time
// with values from the GOOGLE_SERVICES_JSON secret. To run locally, generate it:
// node .github/scripts/write-firebase-options.js \
//   flutter/android/app/google-services.json flutter/lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
  );
}
