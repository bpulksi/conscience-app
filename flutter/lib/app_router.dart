import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _SplashLoader();
        }

        final user = authSnap.data;
        if (user == null) {
          return const _SignInScreen();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _SplashLoader();
            }

            final data = userSnap.data?.data() as Map<String, dynamic>?;
            final onboardingComplete = data?['onboardingComplete'] as bool? ?? false;

            if (!onboardingComplete) {
              return const OnboardingFlow();
            }

            return const DashboardScreen();
          },
        );
      },
    );
  }
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_circle_up, color: Colors.white, size: 48),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signInAnonymously() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.arrow_circle_up, color: Colors.white, size: 80),
              const SizedBox(height: 24),
              const Text(
                'The Open Ascent',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'A free, open system for a balanced life.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _signInAnonymously,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text('Begin — No Account Needed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Free & open source · No paywalls · No tracking',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
