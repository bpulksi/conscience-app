import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

enum WellnessSessionType { breathwork, meditation, yoga }

extension WellnessSessionTypeExt on WellnessSessionType {
  String get label {
    switch (this) {
      case WellnessSessionType.breathwork:
        return 'breathwork';
      case WellnessSessionType.meditation:
        return 'meditation';
      case WellnessSessionType.yoga:
        return 'yoga';
    }
  }

  int get durationSeconds {
    switch (this) {
      case WellnessSessionType.breathwork:
        return 300;
      case WellnessSessionType.meditation:
        return 600;
      case WellnessSessionType.yoga:
        return 900;
    }
  }

  int get coinReward {
    switch (this) {
      case WellnessSessionType.breathwork:
        return 25;
      case WellnessSessionType.meditation:
        return 50;
      case WellnessSessionType.yoga:
        return 75;
    }
  }
}

class WellnessService {
  final _functions = FirebaseFunctions.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  /// Issues a server-side token when a session starts.
  /// Must be called at session start, not completion, to prevent timing fraud.
  Future<String> issueSessionToken(WellnessSessionType type) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final token = _uuid.v4();
    await _firestore.collection('wellnessTokens').doc(token).set({
      'uid': uid,
      'sessionType': type.label,
      'issuedAt': FieldValue.serverTimestamp(),
      'claimed': false,
    });
    return token;
  }

  /// Calls the Cloud Function to validate and award coins.
  /// Returns coins awarded, or throws on fraud/error.
  Future<int> claimReward({
    required WellnessSessionType type,
    required String sessionToken,
  }) async {
    final callable = _functions.httpsCallable('claimWellnessReward');
    final result = await callable.call({
      'sessionType': type.label,
      'sessionToken': sessionToken,
    });
    return result.data['coinsAwarded'] as int;
  }
}
