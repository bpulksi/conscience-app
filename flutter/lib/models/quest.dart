import 'package:cloud_firestore/cloud_firestore.dart';
import 'pillar.dart';

enum QuestDifficulty { novice, journeyman, expert, master }

extension QuestDifficultyExt on QuestDifficulty {
  String get label {
    switch (this) {
      case QuestDifficulty.novice:      return 'Novice';
      case QuestDifficulty.journeyman:  return 'Journeyman';
      case QuestDifficulty.expert:      return 'Expert';
      case QuestDifficulty.master:      return 'Master';
    }
  }

  static QuestDifficulty fromString(String s) {
    switch (s.toLowerCase()) {
      case 'journeyman': return QuestDifficulty.journeyman;
      case 'expert':     return QuestDifficulty.expert;
      case 'master':     return QuestDifficulty.master;
      default:           return QuestDifficulty.novice;
    }
  }
}

enum QuestRecurrence { daily, weekly, oneTime }

extension QuestRecurrenceExt on QuestRecurrence {
  String get label {
    switch (this) {
      case QuestRecurrence.daily:   return 'Daily';
      case QuestRecurrence.weekly:  return 'Weekly';
      case QuestRecurrence.oneTime: return 'One-Time';
    }
  }

  static QuestRecurrence fromString(String s) {
    switch (s.toLowerCase()) {
      case 'weekly':   return QuestRecurrence.weekly;
      case 'one_time': return QuestRecurrence.oneTime;
      default:         return QuestRecurrence.daily;
    }
  }
}

enum QuestStatus { available, active, completed, failed }

extension QuestStatusExt on QuestStatus {
  static QuestStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'active':    return QuestStatus.active;
      case 'completed': return QuestStatus.completed;
      case 'failed':    return QuestStatus.failed;
      default:          return QuestStatus.available;
    }
  }
}

class PillarBonusXP {
  final PillarType pillar;
  final int xp;

  const PillarBonusXP({required this.pillar, required this.xp});

  factory PillarBonusXP.fromMap(Map<String, dynamic> map) {
    return PillarBonusXP(
      pillar: PillarTypeExt.fromId(map['pillar'] as String? ?? 'body'),
      xp: (map['xp'] as num?)?.toInt() ?? 0,
    );
  }
}

class GlobalQuestDefinition {
  final String questId;
  final String name;
  final String description;
  final PillarType pillar;
  final QuestDifficulty difficulty;
  final QuestRecurrence recurrence;
  final int xpReward;
  final int? durationSeconds;
  final String completionCriteria;
  final PillarBonusXP? pillarBonus;
  final int sortOrder;

  const GlobalQuestDefinition({
    required this.questId,
    required this.name,
    required this.description,
    required this.pillar,
    required this.difficulty,
    required this.recurrence,
    required this.xpReward,
    this.durationSeconds,
    required this.completionCriteria,
    this.pillarBonus,
    this.sortOrder = 0,
  });

  bool get isTimerBased => durationSeconds != null;

  factory GlobalQuestDefinition.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final bonusMap = data['pillarBonus'] as Map<String, dynamic>?;
    return GlobalQuestDefinition(
      questId: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      pillar: PillarTypeExt.fromId(data['pillar'] as String? ?? 'body'),
      difficulty: QuestDifficultyExt.fromString(data['difficulty'] as String? ?? 'novice'),
      recurrence: QuestRecurrenceExt.fromString(data['recurrence'] as String? ?? 'daily'),
      xpReward: (data['xpReward'] as num?)?.toInt() ?? 50,
      durationSeconds: (data['durationSeconds'] as num?)?.toInt(),
      completionCriteria: data['completionCriteria'] as String? ?? '',
      pillarBonus: bonusMap != null ? PillarBonusXP.fromMap(bonusMap) : null,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class UserQuest {
  final String questId;
  final PillarType pillar;
  final QuestStatus status;
  final int progressCount;
  final DateTime? completedAt;
  final DateTime? activatedAt;
  final DateTime? lastCompletedAt;
  final QuestRecurrence recurrence;
  final int xpAwarded;
  final GlobalQuestDefinition? definition;

  const UserQuest({
    required this.questId,
    required this.pillar,
    required this.status,
    required this.progressCount,
    this.completedAt,
    this.activatedAt,
    this.lastCompletedAt,
    required this.recurrence,
    required this.xpAwarded,
    this.definition,
  });

  bool get canCompleteToday {
    if (status != QuestStatus.active) return false;
    if (recurrence == QuestRecurrence.oneTime) return true;
    if (lastCompletedAt == null) return true;
    final now = DateTime.now();
    if (recurrence == QuestRecurrence.daily) {
      return lastCompletedAt!.day != now.day ||
             lastCompletedAt!.month != now.month ||
             lastCompletedAt!.year != now.year;
    }
    if (recurrence == QuestRecurrence.weekly) {
      final lastWeek = _isoWeekNumber(lastCompletedAt!);
      final thisWeek = _isoWeekNumber(now);
      return lastWeek != thisWeek || lastCompletedAt!.year != now.year;
    }
    return false;
  }

  static int _isoWeekNumber(DateTime date) {
    final jan1 = DateTime(date.year, 1, 1);
    return ((date.difference(jan1).inDays + jan1.weekday) / 7).ceil();
  }

  UserQuest copyWith({GlobalQuestDefinition? definition}) {
    return UserQuest(
      questId: questId,
      pillar: pillar,
      status: status,
      progressCount: progressCount,
      completedAt: completedAt,
      activatedAt: activatedAt,
      lastCompletedAt: lastCompletedAt,
      recurrence: recurrence,
      xpAwarded: xpAwarded,
      definition: definition ?? this.definition,
    );
  }

  factory UserQuest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserQuest(
      questId: doc.id,
      pillar: PillarTypeExt.fromId(data['pillar'] as String? ?? 'body'),
      status: QuestStatusExt.fromString(data['status'] as String? ?? 'available'),
      progressCount: (data['progressCount'] as num?)?.toInt() ?? 0,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      activatedAt: (data['activatedAt'] as Timestamp?)?.toDate(),
      lastCompletedAt: (data['lastCompletedAt'] as Timestamp?)?.toDate(),
      recurrence: QuestRecurrenceExt.fromString(data['recurrence'] as String? ?? 'daily'),
      xpAwarded: (data['xpAwarded'] as num?)?.toInt() ?? 0,
    );
  }
}
