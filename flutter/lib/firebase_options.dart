// Generated stub — replace by running `flutterfire configure --project=conscience-62d8b`
// See SETUP.md.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not supported — run `flutterfire configure` to add it.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        // Placeholder — real values come from google-services.json /
        // GoogleService-Info.plist after `flutterfire configure`.
        return const FirebaseOptions(
          apiKey: 'REPLACE_ME',
          appId: 'REPLACE_ME',
          messagingSenderId: '311843737311',
          projectId: 'conscience-62d8b',
          storageBucket: 'conscience-62d8b.appspot.com',
        );
      default:
        throw UnsupportedError(
          'Platform ${defaultTargetPlatform.name} is not supported — '
          'run `flutterfire configure` to generate options.',
        );
    }
  }
}
