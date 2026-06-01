import 'package:cloud_firestore/cloud_firestore.dart';
import 'pillar.dart';

class Achievement {
  final String achievementId;
  final String title;
  final String description;
  final String category;
  final DateTime earnedAt;
  final PillarType? pillar;
  final String badgeAsset;
  final bool isNew;

  const Achievement({
    required this.achievementId,
    required this.title,
    required this.description,
    required this.category,
    required this.earnedAt,
    this.pillar,
    required this.badgeAsset,
    required this.isNew,
  });

  factory Achievement.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final pillarStr = data['pillar'] as String?;
    return Achievement(
      achievementId: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'milestone',
      earnedAt: (data['earnedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pillar: pillarStr != null ? PillarTypeExt.fromId(pillarStr) : null,
      badgeAsset: data['badgeAsset'] as String? ?? 'assets/badges/default.png',
      isNew: data['isNew'] as bool? ?? false,
    );
  }
}
