import 'package:flutter/material.dart';
import '../models/quest.dart';

class QuestCard extends StatelessWidget {
  final UserQuest quest;
  final VoidCallback? onTap;

  const QuestCard({super.key, required this.quest, this.onTap});

  @override
  Widget build(BuildContext context) {
    final def = quest.definition;
    final pillar = quest.pillar;
    final canComplete = quest.canCompleteToday;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: quest.status == QuestStatus.completed
          ? Colors.grey.shade50
          : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: pillar.lightColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(pillar.icon, color: pillar.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            def?.name ?? quest.questId,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: quest.status == QuestStatus.completed
                                  ? Colors.grey.shade500
                                  : Colors.black87,
                              decoration: quest.status == QuestStatus.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        _XpChip(xp: def?.xpReward ?? 0, pillarColor: pillar.color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _PillarChip(label: pillar.shortLabel, color: pillar.color),
                        const SizedBox(width: 6),
                        if (def != null) _DifficultyChip(difficulty: def.difficulty),
                        const SizedBox(width: 6),
                        _RecurrenceChip(recurrence: quest.recurrence),
                      ],
                    ),
                    if (quest.status == QuestStatus.active && !canComplete) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Come back tomorrow',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (quest.status == QuestStatus.active && canComplete)
                Icon(Icons.chevron_right, color: pillar.color),
              if (quest.status == QuestStatus.completed)
                Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _XpChip extends StatelessWidget {
  final int xp;
  final Color pillarColor;
  const _XpChip({required this.xp, required this.pillarColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: pillarColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '+$xp XP',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pillarColor),
      ),
    );
  }
}

class _PillarChip extends StatelessWidget {
  final String label;
  final Color color;
  const _PillarChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final QuestDifficulty difficulty;
  const _DifficultyChip({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (difficulty) {
      case QuestDifficulty.novice:     color = Colors.green; break;
      case QuestDifficulty.journeyman: color = Colors.blue; break;
      case QuestDifficulty.expert:     color = Colors.orange; break;
      case QuestDifficulty.master:     color = Colors.purple; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(difficulty.label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _RecurrenceChip extends StatelessWidget {
  final QuestRecurrence recurrence;
  const _RecurrenceChip({required this.recurrence});

  @override
  Widget build(BuildContext context) {
    return Text(
      recurrence.label,
      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
    );
  }
}
