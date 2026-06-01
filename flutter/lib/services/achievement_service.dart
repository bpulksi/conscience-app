import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/achievement.dart';

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<Achievement>> watchAchievements() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .orderBy('earnedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Achievement.fromDoc).toList());
  }

  Future<int> getUnviewedCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .where('isNew', isEqualTo: true)
        .get();
    return snap.size;
  }

  Future<void> markAllViewed() async {
    final uid = _uid;
    if (uid == null) return;
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .where('isNew', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isNew': false});
    }
    await batch.commit();
  }

  Future<List<String>> checkAndAward() async {
    final callable = _functions.httpsCallable('checkAndAwardAchievements');
    final result = await callable.call({});
    final data = result.data as Map<dynamic, dynamic>;
    final earned = data['earned'] as List<dynamic>? ?? [];
    return earned.map((e) => e.toString()).toList();
  }
}
