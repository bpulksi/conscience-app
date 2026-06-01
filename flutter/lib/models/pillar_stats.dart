import 'package:cloud_firestore/cloud_firestore.dart';
import 'pillar.dart';

class PillarStats {
  final PillarType pillar;
  final int xp;
  final int level;
  final String levelTitle;
  final int xpToNextLevel;

  const PillarStats({
    required this.pillar,
    required this.xp,
    required this.level,
    required this.levelTitle,
    required this.xpToNextLevel,
  });

  double get progressFraction {
    if (level >= 100) return 1.0;
    final xpAtCurrentLevel = _xpForLevel(level);
    final xpAtNextLevel = _xpForLevel(level + 1);
    final range = xpAtNextLevel - xpAtCurrentLevel;
    if (range <= 0) return 1.0;
    return ((xp - xpAtCurrentLevel) / range).clamp(0.0, 1.0);
  }

  static int _xpForLevel(int level) => 100 * level * (level - 1) ~/ 2;

  factory PillarStats.fromDoc(DocumentSnapshot doc, PillarType pillar) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PillarStats(
      pillar: pillar,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      level: (data['level'] as num?)?.toInt() ?? 1,
      levelTitle: data['levelTitle'] as String? ?? 'The Dormant',
      xpToNextLevel: (data['xpToNextLevel'] as num?)?.toInt() ?? 100,
    );
  }

  factory PillarStats.initial(PillarType pillar) {
    return PillarStats(
      pillar: pillar,
      xp: 0,
      level: 1,
      levelTitle: _initialTitle(pillar),
      xpToNextLevel: 100,
    );
  }

  static String _initialTitle(PillarType pillar) {
    switch (pillar) {
      case PillarType.body:    return 'The Dormant';
      case PillarType.mind:    return 'The Curious';
      case PillarType.spirit:  return 'The Restless';
      case PillarType.career:  return 'The Idle';
      case PillarType.karma:   return 'The Indifferent';
    }
  }
}
