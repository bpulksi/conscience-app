import 'package:flutter/material.dart';

import '../../services/native_bridge.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final _bridge = NativeBridge();
  PermissionStatus? _status;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after returning from the settings deep-link.
    if (state == AppLifecycleState.resumed && _status == PermissionStatus.needsSettings) {
      _request();
    }
  }

  Future<void> _request() async {
    setState(() => _checking = true);
    final status = await _bridge.requestPermissions();
    if (!mounted) return;
    setState(() {
      _status = status;
      _checking = false;
    });

    if (status == PermissionStatus.granted) {
      Navigator.of(context).pushReplacementNamed('/onboarding/partner');
    } else if (status == PermissionStatus.needsSettings) {
      await _showSettingsDialog();
    }
  }

  Future<void> _showSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Almost there'),
        content: const Text(
          'Conscience needs to observe which apps you open so it can step in '
          'when you hit your daily limit. Grant the Accessibility permission '
          '(or Screen Time on iOS) in the next screen, then return here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _bridge.openPermissionSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.shield_moon_rounded, size: 64),
              const SizedBox(height: 24),
              Text(
                'Grant monitoring access',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Conscience uses your device\'s built-in accessibility and '
                'Screen Time APIs to watch only the apps you choose. Nothing '
                'leaves your device without your consent.',
              ),
              const Spacer(),
              if (_status == PermissionStatus.denied)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Permission denied. You can retry below.',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _checking ? null : _request,
                  child: _checking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pushReplacementNamed('/onboarding/partner'),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
