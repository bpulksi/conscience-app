import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/partner_service.dart';
import '../services/wellness_service.dart';
import '../widgets/function_result_card.dart';

/// Drop-in screen that calls each Cloud Function and displays its output.
///
/// Integrate into your app's router, or push it directly:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const FunctionOutputScreen()));
class FunctionOutputScreen extends StatefulWidget {
  const FunctionOutputScreen({super.key});

  @override
  State<FunctionOutputScreen> createState() => _FunctionOutputScreenState();
}

class _FunctionOutputScreenState extends State<FunctionOutputScreen> {
  final _wellness = WellnessService();
  final _partner = PartnerService();

  final _inviteCodeController = TextEditingController();

  FunctionResult? _claimResult;
  FunctionResult? _requestExtResult;
  FunctionResult? _linkResult;
  FunctionResult? _unlinkResult;
  FunctionResult? _inviteResult;

  bool _claimLoading = false;
  bool _extLoading = false;
  bool _linkLoading = false;
  bool _unlinkLoading = false;
  bool _inviteLoading = false;

  // ── Wellness ─────────────────────────────────────────────────────────────

  Future<void> _claimWellness() async {
    setState(() => _claimLoading = true);
    try {
      final token = await _wellness.issueSessionToken(WellnessSessionType.meditation);
      final coins = await _wellness.claimReward(
        type: WellnessSessionType.meditation,
        sessionToken: token,
      );
      setState(() => _claimResult = FunctionResult.success(
            label: 'claimWellnessReward',
            output: '+$coins coins awarded',
          ));
    } on FirebaseFunctionsException catch (e) {
      setState(() => _claimResult = FunctionResult.failure(
            label: 'claimWellnessReward',
            error: '[${e.code}] ${e.message}',
          ));
    } catch (e) {
      setState(() => _claimResult = FunctionResult.failure(
            label: 'claimWellnessReward',
            error: e.toString(),
          ));
    } finally {
      setState(() => _claimLoading = false);
    }
  }

  // ── Partner – Generate Invite ─────────────────────────────────────────────

  Future<void> _generateInvite() async {
    setState(() => _inviteLoading = true);
    try {
      final code = await _partner.generateInviteCode();
      setState(() => _inviteResult = FunctionResult.success(
            label: 'generateInviteCode',
            output: 'Invite code: $code',
          ));
    } catch (e) {
      setState(() => _inviteResult = FunctionResult.failure(
            label: 'generateInviteCode',
            error: e.toString(),
          ));
    } finally {
      setState(() => _inviteLoading = false);
    }
  }

  // ── Partner – Link ────────────────────────────────────────────────────────

  Future<void> _linkPartner() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _linkLoading = true);
    try {
      await _partner.linkPartner(code);
      setState(() => _linkResult = FunctionResult.success(
            label: 'linkAccountabilityPartner',
            output: 'Linked successfully with code $code',
          ));
    } on FirebaseFunctionsException catch (e) {
      setState(() => _linkResult = FunctionResult.failure(
            label: 'linkAccountabilityPartner',
            error: '[${e.code}] ${e.message}',
          ));
    } catch (e) {
      setState(() => _linkResult = FunctionResult.failure(
            label: 'linkAccountabilityPartner',
            error: e.toString(),
          ));
    } finally {
      setState(() => _linkLoading = false);
    }
  }

  // ── Partner – Unlink ──────────────────────────────────────────────────────

  Future<void> _unlinkPartner() async {
    setState(() => _unlinkLoading = true);
    try {
      await _partner.unlinkPartner();
      setState(() => _unlinkResult = FunctionResult.success(
            label: 'unlinkAccountabilityPartner',
            output: 'Partner unlinked successfully',
          ));
    } on FirebaseFunctionsException catch (e) {
      setState(() => _unlinkResult = FunctionResult.failure(
            label: 'unlinkAccountabilityPartner',
            error: '[${e.code}] ${e.message}',
          ));
    } catch (e) {
      setState(() => _unlinkResult = FunctionResult.failure(
            label: 'unlinkAccountabilityPartner',
            error: e.toString(),
          ));
    } finally {
      setState(() => _unlinkLoading = false);
    }
  }

  // ── Extension Request ─────────────────────────────────────────────────────

  Future<void> _requestExtension() async {
    setState(() => _extLoading = true);
    try {
      final requestId = await _partner.requestExtension();
      setState(() => _requestExtResult = FunctionResult.success(
            label: 'requestExtension',
            output: 'Request sent — ID: $requestId',
          ));
    } on FirebaseFunctionsException catch (e) {
      setState(() => _requestExtResult = FunctionResult.failure(
            label: 'requestExtension',
            error: '[${e.code}] ${e.message}',
          ));
    } catch (e) {
      setState(() => _requestExtResult = FunctionResult.failure(
            label: 'requestExtension',
            error: e.toString(),
          ));
    } finally {
      setState(() => _extLoading = false);
    }
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Function Output')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Wellness ───────────────────────────────────────────────────────
          _SectionHeader(title: 'Wellness'),
          _ActionTile(
            label: 'Claim Meditation Reward',
            subtitle: 'claimWellnessReward (meditation → 50 coins)',
            loading: _claimLoading,
            onTap: _claimWellness,
          ),
          FunctionResultCard(result: _claimResult),

          const Divider(height: 32),

          // ── Partner – Invite ───────────────────────────────────────────────
          _SectionHeader(title: 'Partner Linking'),
          _ActionTile(
            label: 'Generate Invite Code',
            subtitle: 'Writes a one-time code to Firestore',
            loading: _inviteLoading,
            onTap: _generateInvite,
          ),
          FunctionResultCard(result: _inviteResult),

          const SizedBox(height: 12),
          TextField(
            controller: _inviteCodeController,
            decoration: const InputDecoration(
              labelText: 'Partner invite code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            label: 'Link Partner',
            subtitle: 'linkAccountabilityPartner',
            loading: _linkLoading,
            onTap: _linkPartner,
          ),
          FunctionResultCard(result: _linkResult),

          const SizedBox(height: 8),
          _ActionTile(
            label: 'Unlink Partner',
            subtitle: 'unlinkAccountabilityPartner',
            loading: _unlinkLoading,
            onTap: _unlinkPartner,
          ),
          FunctionResultCard(result: _unlinkResult),

          const Divider(height: 32),

          // ── Extension ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Extension Request'),
          _ActionTile(
            label: 'Request 10-min Extension',
            subtitle: 'requestExtension — notifies your partner',
            loading: _extLoading,
            onTap: _requestExtension,
          ),
          FunctionResultCard(result: _requestExtResult),
        ],
      ),
    );
  }
}

// ── Private helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Colors.grey.shade600, letterSpacing: 0.8),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
      ),
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonal(
              onPressed: onTap,
              child: const Text('Call'),
            ),
    );
  }
}
