import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const prefOnboardingComplete = 'onboardingComplete';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(SplashScreen.prefOnboardingComplete) ?? false;
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      done ? '/home' : '/onboarding/permissions',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_alt_rounded, size: 72),
            SizedBox(height: 16),
            Text('Conscience', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
