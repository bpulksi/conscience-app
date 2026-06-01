import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/pillar.dart';

class SessionClaimResult {
  final int xpAwarded;
  final int bonusXp;
  final String bonusPillar;
  final int newLevel;
  final String newTitle;

  const SessionClaimResult({
    required this.xpAwarded,
    required this.bonusXp,
    required this.bonusPillar,
    required this.newLevel,
    required this.newTitle,
  });
}

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final _functions = FirebaseFunctions.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  /// Issues a server-side token when a session starts.
  /// Must be called at session start (not completion) to prevent timing fraud.
  Future<String> issueSessionToken({
    required PillarType pillar,
    required String activityType,
    required int durationRequired,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final token = _uuid.v4();
    await _firestore.collection('sessionTokens').doc(token).set({
      'uid': uid,
      'pillar': pillar.id,
      'activityType': activityType,
      'durationRequired': durationRequired,
      'issuedAt': FieldValue.serverTimestamp(),
      'claimed': false,
    });
    return token;
  }

  /// Calls the Cloud Function to validate elapsed time and award XP.
  Future<SessionClaimResult> claimSessionXP({
    required PillarType pillar,
    required String activityType,
    required String sessionToken,
  }) async {
    final callable = _functions.httpsCallable('claimSessionXP');
    final result = await callable.call({
      'pillar': pillar.id,
      'activityType': activityType,
      'sessionToken': sessionToken,
    });
    final data = result.data as Map<dynamic, dynamic>;
    return SessionClaimResult(
      xpAwarded: (data['xpAwarded'] as num?)?.toInt() ?? 0,
      bonusXp: (data['bonusXp'] as num?)?.toInt() ?? 0,
      bonusPillar: data['bonusPillar'] as String? ?? '',
      newLevel: (data['newLevel'] as num?)?.toInt() ?? 1,
      newTitle: data['newTitle'] as String? ?? '',
    );
  }
}
