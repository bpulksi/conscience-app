import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/quest.dart';
import '../widgets/function_result_card.dart';
import '../services/quest_service.dart';
import 'session_timer_screen.dart';

class QuestDetailScreen extends StatefulWidget {
  final UserQuest quest;

  const QuestDetailScreen({super.key, required this.quest});

  @override
  State<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends State<QuestDetailScreen> {
  FunctionResult? _result;
  bool _loading = false;

  UserQuest get _quest => widget.quest;
  GlobalQuestDefinition? get _def => _quest.definition;

  Future<void> _completeQuest() async {
    setState(() { _loading = true; _result = null; });
    try {
      final result = await QuestService().completeQuest(_quest.questId);
      setState(() {
        _result = FunctionResult.success(
          label: 'Quest Complete!',
          output: '+${result.xpAwarded} XP earned. ${_quest.pillar.shortLabel} is now Level ${result.newLevel} — ${result.newTitle}',
        );
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _result = FunctionResult.failure(label: 'Quest Failed', error: e.message ?? e.code);
      });
    } catch (e) {
      setState(() {
        _result = FunctionResult.failure(label: 'Error', error: e.toString());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = _def;
    final pillar = _quest.pillar;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: pillar.lightColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(pillar.icon, color: pillar.color, size: 14),
                  const SizedBox(width: 4),
                  Text(pillar.label, style: TextStyle(color: pillar.color, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              def?.name ?? _quest.questId,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
            ),
            const SizedBox(height: 8),
            if (def != null) Row(
              children: [
                _Chip(label: def.difficulty.label, color: _difficultyColor(def.difficulty)),
                const SizedBox(width: 8),
                _Chip(label: def.recurrence.label, color: Colors.grey),
                const SizedBox(width: 8),
                _Chip(label: '+${def.xpReward} XP', color: pillar.color),
              ],
            ),
            const SizedBox(height: 20),
            if (def != null) ...[
              Text(def.description, style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey.shade800)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Completion Criteria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(def.completionCriteria, style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.5)),
                  ],
                ),
              ),
              if (def.pillarBonus != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: def.pillarBonus!.pillar.lightColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, color: def.pillarBonus!.pillar.color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bonus: +${def.pillarBonus!.xp} XP to ${def.pillarBonus!.pillar.label}',
                          style: TextStyle(color: def.pillarBonus!.pillar.color, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            if (_quest.progressCount > 0) ...[
              Text(
                'Completed ${_quest.progressCount} time${_quest.progressCount > 1 ? "s" : ""}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            FunctionResultCard(result: _result),
            const SizedBox(height: 16),
            if (_quest.status == QuestStatus.active && _quest.canCompleteToday) ...[
              if (def?.isTimerBased == true)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionTimerScreen(
                          quest: _quest,
                          definition: def!,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.timer),
                    label: const Text('Start Timer Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: pillar.color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _completeQuest,
                    icon: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: const Text('Mark Complete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: pillar.color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
            ] else if (_quest.status == QuestStatus.active && !_quest.canCompleteToday)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Already completed for today. Come back tomorrow.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(QuestDifficulty d) {
    switch (d) {
      case QuestDifficulty.novice:     return Colors.green;
      case QuestDifficulty.journeyman: return Colors.blue;
      case QuestDifficulty.expert:     return Colors.orange;
      case QuestDifficulty.master:     return Colors.purple;
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
