import 'package:cloud_firestore/cloud_firestore.dart';
import 'pillar.dart';

class Session {
  final String sessionId;
  final PillarType pillar;
  final String activityType;
  final int durationSeconds;
  final int xpAwarded;
  final PillarType? bonusXpPillar;
  final int bonusXp;
  final String sessionToken;
  final DateTime completedAt;

  const Session({
    required this.sessionId,
    required this.pillar,
    required this.activityType,
    required this.durationSeconds,
    required this.xpAwarded,
    this.bonusXpPillar,
    required this.bonusXp,
    required this.sessionToken,
    required this.completedAt,
  });

  factory Session.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final bonusPillarStr = data['bonusXpPillar'] as String?;
    return Session(
      sessionId: doc.id,
      pillar: PillarTypeExt.fromId(data['pillar'] as String? ?? 'body'),
      activityType: data['activityType'] as String? ?? '',
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
      xpAwarded: (data['xpAwarded'] as num?)?.toInt() ?? 0,
      bonusXpPillar: bonusPillarStr != null ? PillarTypeExt.fromId(bonusPillarStr) : null,
      bonusXp: (data['bonusXp'] as num?)?.toInt() ?? 0,
      sessionToken: data['sessionToken'] as String? ?? '',
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
