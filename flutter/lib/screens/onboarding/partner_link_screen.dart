import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/partner_service.dart';
import '../splash_screen.dart';

class PartnerLinkScreen extends StatefulWidget {
  const PartnerLinkScreen({super.key});

  @override
  State<PartnerLinkScreen> createState() => _PartnerLinkScreenState();
}

class _PartnerLinkScreenState extends State<PartnerLinkScreen> {
  final _partner = PartnerService();
  final _codeController = TextEditingController();

  String? _generatedCode;
  bool _busy = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await _partner.generateInviteCode();
      setState(() => _generatedCode = code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _partner.linkPartner(code);
      await _finish();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SplashScreen.prefOnboardingComplete, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accountability partner'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _finish,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Invite a trusted friend to review your extension requests when '
              'you hit your daily limit.',
            ),
            const SizedBox(height: 24),
            _card(
              title: 'Generate a code',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_generatedCode != null)
                    Row(
                      children: [
                        SelectableText(
                          _generatedCode!,
                          style: const TextStyle(
                            fontSize: 22,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _generatedCode!),
                          ),
                        ),
                      ],
                    )
                  else
                    FilledButton.tonal(
                      onPressed: _busy ? null : _generate,
                      child: const Text('Create code'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _card(
              title: 'Enter your partner\'s code',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Invite code',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _link,
                    child: const Text('Link partner'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
