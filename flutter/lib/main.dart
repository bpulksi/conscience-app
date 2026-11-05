import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/function_output_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/partner_link_screen.dart';
import 'screens/onboarding/permissions_screen.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Anonymous sign-in so uid-gated Firestore reads and Cloud Functions work
  // from the first launch. Replace with email/Apple auth later.
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
    }
  }

  runApp(const ConscienceApp());
}

class ConscienceApp extends StatelessWidget {
  const ConscienceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conscience',
      debugShowCheckedModeBanner: false,
      theme: ConscienceTheme.dark,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/onboarding/permissions': (_) => const PermissionsScreen(),
        '/onboarding/partner': (_) => const PartnerLinkScreen(),
        '/home': (_) => const HomeScreen(),
        '/dev': (_) => const FunctionOutputScreen(),
      },
    );
  }
}
