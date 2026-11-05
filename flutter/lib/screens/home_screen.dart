import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../services/native_bridge.dart';
import 'avatar_cast_screen.dart';
import '../services/partner_service.dart';
import '../services/wellness_service.dart';
import '../widgets/avatar_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _rechargeTab = 1;

  final _bridge = NativeBridge();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openDeepLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _openDeepLink();
  }

  /// The block screen's button sends the person straight to Recharge.
  Future<void> _openDeepLink() async {
    final link = await _bridge.consumePendingDeepLink();
    if (link == 'rechargeHub' && mounted) setState(() => _tab = _rechargeTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conscience'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'dev') Navigator.of(context).pushNamed('/dev');
              if (v == 'cast') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AvatarCastScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cast', child: Text('Choose avatar')),
              PopupMenuItem(value: 'dev', child: Text('Dev tools')),
            ],
          ),
        ],
      ),
      // IndexedStack keeps a running session's timer alive across tab switches.
      body: IndexedStack(
        index: _tab,
        children: const [_TodayTab(), _RechargeTab(), _PartnersTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.spa_rounded), label: 'Recharge'),
          NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Partners'),
        ],
      ),
    );
  }
}

// ── Today ────────────────────────────────────────────────────────────────────

class _TodayTab extends StatefulWidget {
  const _TodayTab();

  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> with WidgetsBindingObserver {
  final _bridge = NativeBridge();
  int _dailyLimit = 60;
  bool _toughLove = false;
  UsageStatus? _usage;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUsage(syncLimit: true);
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => _loadUsage());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadUsage();
  }

  Future<void> _loadUsage({bool syncLimit = false}) async {
    final usage = await _bridge.getUsageStatus();
    if (!mounted) return;
    setState(() {
      _usage = usage;
      if (syncLimit) _dailyLimit = usage.dailyLimitMinutes;
    });
  }

  /// For trying the full loop on a phone. Remove before release.
  Future<void> _useTestLimit() async {
    setState(() => _dailyLimit = 2);
    await _bridge.resetBlock();
    await _configure();
  }

  Future<void> _configure() async {
    await _bridge.configureMonitoring(
      packageNames: const [
        'com.instagram.android',
        'com.zhiliaoapp.musically',
        'com.twitter.android',
        'com.google.android.youtube',
        'com.reddit.frontpage',
      ],
      bundleIds: const [],
      dailyLimitMinutes: _dailyLimit,
      toughLove: _toughLove,
    );
    await _loadUsage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Monitoring set to $_dailyLimit min / day')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usage = _usage;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          StreamBuilder<AvatarStage>(
            stream: _bridge.avatarStageStream,
            initialData: AvatarStage.zen,
            builder: (_, snap) {
              final stage = snap.data ?? AvatarStage.zen;
              return Column(
                children: [
                  AvatarView(stage: stage),
                  const SizedBox(height: 12),
                  Text(
                    _moodLabel(stage),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (usage != null)
            Text(
              'Used ${usage.usedMinutes} of '
              '${usage.dailyLimitMinutes + usage.earnedMinutes} min today'
              '${usage.earnedMinutes > 0 ? ' (${usage.earnedMinutes} earned)' : ''}',
            ),
          const SizedBox(height: 16),
          Text('Daily limit: $_dailyLimit minutes',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            min: 15,
            max: 240,
            divisions: 15,
            value: _dailyLimit.clamp(15, 240).toDouble(),
            label: '$_dailyLimit min',
            onChanged: (v) => setState(() => _dailyLimit = v.toInt()),
          ),
          SwitchListTile(
            value: _toughLove,
            onChanged: (v) => setState(() => _toughLove = v),
            title: const Text('Tough-love mode'),
            subtitle: const Text('Harder to bypass when you hit your limit'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _configure,
              child: const Text('Save monitoring settings'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _useTestLimit,
            child: const Text('Test: reset today and use a 2-minute limit'),
          ),
        ],
      ),
    );
  }

  String _moodLabel(AvatarStage s) {
    switch (s) {
      case AvatarStage.zen:
        return 'Zen — you\'re good';
      case AvatarStage.impatient:
        return 'Getting restless';
      case AvatarStage.furious:
        return 'Daily limit reached';
    }
  }
}

// ── Recharge ─────────────────────────────────────────────────────────────────

class _RechargeTab extends StatefulWidget {
  const _RechargeTab();

  @override
  State<_RechargeTab> createState() => _RechargeTabState();
}

class _RechargeTabState extends State<_RechargeTab> {
  final _wellness = WellnessService();
  final _bridge = NativeBridge();

  WellnessSessionType? _running;
  int _remainingSeconds = 0;
  Timer? _timer;
  String? _status;

  Future<void> _start(WellnessSessionType type) async {
    if (_running != null) return;
    setState(() {
      _running = type;
      _remainingSeconds = type.durationSeconds;
      _status = 'Starting…';
    });

    String token;
    try {
      token = await _wellness.startSession(type);
    } catch (e) {
      setState(() {
        _running = null;
        _status = 'Could not start: $e';
      });
      return;
    }

    setState(() => _status = 'In session');
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_remainingSeconds <= 1) {
        t.cancel();
        await _complete(type, token);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _complete(WellnessSessionType type, String token) async {
    setState(() => _status = 'Claiming reward…');
    try {
      final coins = await _wellness.claimReward(sessionToken: token);
      // Only after the server accepts the session.
      await _bridge.grantExtension(durationMinutes: type.earnedMinutes);
      if (!mounted) return;
      setState(() => _status =
          '+$coins coins and ${type.earnedMinutes} more minutes today');
    } on FirebaseFunctionsException catch (e) {
      setState(() => _status = 'Reward failed: [${e.code}] ${e.message}');
    } catch (e) {
      setState(() => _status = 'Reward failed: $e');
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  void _cancel() {
    _timer?.cancel();
    setState(() {
      _running = null;
      _remainingSeconds = 0;
      _status = 'Session cancelled';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_running != null) {
      return _runningView();
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Recharge to earn time',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        for (final type in WellnessSessionType.values)
          Card(
            child: ListTile(
              leading: const Icon(Icons.self_improvement_rounded),
              title: Text(type.label[0].toUpperCase() + type.label.substring(1)),
              subtitle: Text(
                '${(type.durationSeconds / 60).round()} min · +${type.earnedMinutes} min of screen time',
              ),
              trailing: FilledButton(
                onPressed: () => _start(type),
                child: const Text('Start'),
              ),
            ),
          ),
        if (_status != null) ...[
          const SizedBox(height: 16),
          Text(_status!, textAlign: TextAlign.center),
        ],
      ],
    );
  }

  Widget _runningView() {
    final total = _running!.durationSeconds;
    final progress = 1 - (_remainingSeconds / total);
    final mm = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                  ),
                ),
                Text('$mm:$ss',
                    style: Theme.of(context).textTheme.displaySmall),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(_status ?? '', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          TextButton(onPressed: _cancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

// ── Partners ─────────────────────────────────────────────────────────────────

class _PartnersTab extends StatefulWidget {
  const _PartnersTab();

  @override
  State<_PartnersTab> createState() => _PartnersTabState();
}

class _PartnersTabState extends State<_PartnersTab> {
  final _partner = PartnerService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExtensionRequest>>(
      stream: _partner.incomingRequests,
      builder: (_, snap) {
        final reqs = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (reqs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No pending extension requests.\nYou\'ll see them here when '
                'your partner asks for more time.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reqs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final r = reqs[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.requesterName,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('Expires: ${r.expiresAt.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () =>
                              _partner.respondToRequest(r.id, false),
                          child: const Text('Deny'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () =>
                              _partner.respondToRequest(r.id, true),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
