import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';

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

  /// Starts a session on the server, which records the start time.
  /// Call when the session begins. Starting a new one replaces any earlier one.
  Future<String> startSession(WellnessSessionType type) async {
    final callable = _functions.httpsCallable('startWellnessSession');
    final result = await callable.call({'sessionType': type.label});
    return result.data['sessionToken'] as String;
  }

  /// Claims the reward once the session's time is up.
  /// Returns coins awarded. Throws [FirebaseFunctionsException] if the session
  /// is too short, expired, replaced or already claimed.
  Future<int> claimReward({required String sessionToken}) async {
    final callable = _functions.httpsCallable('claimWellnessReward');
    final result = await callable.call({'sessionToken': sessionToken});
    return result.data['coinsAwarded'] as int;
  }
}
