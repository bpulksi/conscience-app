import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/pillar.dart';
import '../models/pillar_stats.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<UserProfile> watchProfile() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? UserProfile.fromDoc(snap) : UserProfile.empty(uid));
  }

  Stream<List<PillarStats>> watchAllPillars() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('pillars')
        .snapshots()
        .map((snap) {
      final byId = {for (final doc in snap.docs) doc.id: doc};
      return allPillars.map((p) {
        final doc = byId[p.id];
        return doc != null ? PillarStats.fromDoc(doc, p) : PillarStats.initial(p);
      }).toList();
    });
  }

  Future<UserProfile?> getProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.exists ? UserProfile.fromDoc(snap) : null;
  }

  Future<void> completeOnboarding({
    required String displayName,
    required String archetype,
    required String archetypeLabel,
    required String customTitle,
    required Map<String, String> goals,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final batch = _firestore.batch();

    final userRef = _firestore.collection('users').doc(uid);
    batch.set(userRef, {
      'displayName': displayName,
      'customTitle': customTitle,
      'archetype': archetype,
      'archetypeLabel': archetypeLabel,
      'totalAscentScore': 5,
      'currentStreak': 0,
      'longestStreak': 0,
      'lastActivityDate': null,
      'goals': goals,
      'onboardingComplete': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final initialTitles = {
      'body':   'The Dormant',
      'mind':   'The Curious',
      'spirit': 'The Restless',
      'career': 'The Idle',
      'karma':  'The Indifferent',
    };

    for (final p in allPillars) {
      final pillarRef = userRef.collection('pillars').doc(p.id);
      batch.set(pillarRef, {
        'pillarId': p.id,
        'xp': 0,
        'level': 1,
        'levelTitle': initialTitles[p.id]!,
        'xpToNextLevel': 100,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
