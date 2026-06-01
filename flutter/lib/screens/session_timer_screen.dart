import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/quest.dart';
import '../services/session_service.dart';
import '../widgets/function_result_card.dart';

class SessionTimerScreen extends StatefulWidget {
  final UserQuest quest;
  final GlobalQuestDefinition definition;

  const SessionTimerScreen({
    super.key,
    required this.quest,
    required this.definition,
  });

  @override
  State<SessionTimerScreen> createState() => _SessionTimerScreenState();
}

class _SessionTimerScreenState extends State<SessionTimerScreen> {
  final _sessionService = SessionService();

  String? _sessionToken;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _running = false;
  bool _claiming = false;
  bool _claimed = false;
  FunctionResult? _result;

  int get _totalSeconds => widget.definition.durationSeconds ?? 600;

  double get _progress => (_elapsedSeconds / _totalSeconds).clamp(0.0, 1.0);

  bool get _canClaim => _sessionToken != null && _elapsedSeconds >= _totalSeconds;

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startSession() async {
    try {
      final def = widget.definition;
      final activityType = _activityTypeFor(def.questId);
      final token = await _sessionService.issueSessionToken(
        pillar: widget.quest.pillar,
        activityType: activityType,
        durationRequired: _totalSeconds,
      );
      setState(() {
        _sessionToken = token;
        _running = true;
        _elapsedSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsedSeconds++);
        if (_elapsedSeconds >= _totalSeconds && _canClaim && !_claimed) {
          // Timer reached — auto-prompt claim
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _claimXP() async {
    if (_sessionToken == null || _claiming || _claimed) return;
    setState(() { _claiming = true; _result = null; });
    try {
      final def = widget.definition;
      final activityType = _activityTypeFor(def.questId);
      final claimResult = await _sessionService.claimSessionXP(
        pillar: widget.quest.pillar,
        activityType: activityType,
        sessionToken: _sessionToken!,
      );
      _timer?.cancel();
      setState(() {
        _claimed = true;
        _running = false;
        String msg = '+${claimResult.xpAwarded} XP to ${widget.quest.pillar.label}';
        if (claimResult.bonusXp > 0) {
          msg += ' · +${claimResult.bonusXp} bonus XP to ${claimResult.bonusPillar}';
        }
        msg += '\nNow Level ${claimResult.newLevel} — ${claimResult.newTitle}';
        _result = FunctionResult.success(label: 'Session Complete!', output: msg);
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _result = FunctionResult.failure(label: 'Claim Failed', error: e.message ?? e.code);
      });
    } catch (e) {
      setState(() {
        _result = FunctionResult.failure(label: 'Error', error: e.toString());
      });
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  String _activityTypeFor(String questId) {
    if (questId.contains('meditation')) return 'meditation';
    if (questId.contains('breathwork') || questId.contains('breath_reset')) return 'breathwork';
    if (questId.contains('yoga')) return 'yoga';
    if (questId.contains('deep_work') || questId.contains('pomodoro')) return 'deep_work';
    if (questId.contains('study') || questId.contains('course') || questId.contains('chapter')) return 'study';
    if (questId.contains('gratitude') || questId.contains('journal')) return 'journaling';
    if (questId.contains('exercise') || questId.contains('pushup') || questId.contains('run')) return 'exercise';
    return 'study';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pillar = widget.quest.pillar;
    final def = widget.definition;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(def.name, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Timer ring
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(pillar.color),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _running || _claimed
                              ? _formatTime(_elapsedSeconds)
                              : _formatTime(_totalSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          _claimed
                              ? 'Complete!'
                              : _running
                                  ? 'elapsed'
                                  : 'duration',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                def.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${pillar.label} · +${def.xpReward} XP',
                style: TextStyle(color: pillar.color, fontSize: 14),
              ),
              if (def.pillarBonus != null) ...[
                const SizedBox(height: 4),
                Text(
                  '+ Bonus ${def.pillarBonus!.xp} XP to ${def.pillarBonus!.pillar.label}',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
              const SizedBox(height: 32),
              FunctionResultCard(result: _result),
              const Spacer(),
              if (!_running && !_claimed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _startSession,
                    style: FilledButton.styleFrom(
                      backgroundColor: pillar.color,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Start Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (_running) ...[
                if (_canClaim)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _claiming ? null : _claimXP,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _claiming
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text('Claim XP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                else
                  Text(
                    '${_formatTime(_totalSeconds - _elapsedSeconds)} remaining',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
              ],
              if (_claimed) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: pillar.color,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
