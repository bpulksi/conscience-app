import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String customTitle;
  final String archetype;
  final String archetypeLabel;
  final int totalAscentScore;
  final int currentStreak;
  final int longestStreak;
  final Map<String, String> goals;
  final bool onboardingComplete;
  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.customTitle,
    required this.archetype,
    required this.archetypeLabel,
    required this.totalAscentScore,
    required this.currentStreak,
    required this.longestStreak,
    required this.goals,
    required this.onboardingComplete,
    this.createdAt,
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawGoals = data['goals'] as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Ascendant',
      customTitle: data['customTitle'] as String? ?? 'The Scholar',
      archetype: data['archetype'] as String? ?? 'scholar',
      archetypeLabel: data['archetypeLabel'] as String? ?? 'The Scholar',
      totalAscentScore: (data['totalAscentScore'] as num?)?.toInt() ?? 5,
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      goals: rawGoals.map((k, v) => MapEntry(k, v.toString())),
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserProfile.empty(String uid) => UserProfile(
    uid: uid,
    displayName: '',
    customTitle: 'The Scholar',
    archetype: 'scholar',
    archetypeLabel: 'The Scholar',
    totalAscentScore: 5,
    currentStreak: 0,
    longestStreak: 0,
    goals: {},
    onboardingComplete: false,
  );
}
