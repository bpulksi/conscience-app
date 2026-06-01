import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/quest.dart';
import '../models/pillar.dart';

class QuestCompletionResult {
  final int xpAwarded;
  final int newLevel;
  final String newTitle;

  const QuestCompletionResult({
    required this.xpAwarded,
    required this.newLevel,
    required this.newTitle,
  });
}

class QuestService {
  static final QuestService _instance = QuestService._internal();
  factory QuestService() => _instance;
  QuestService._internal();

  final _functions = FirebaseFunctions.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<UserQuest>> watchUserQuests() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('quests')
        .snapshots()
        .asyncMap((snap) async {
      final globalDefs = await _fetchGlobalDefs(snap.docs.map((d) => d.id).toList());
      return snap.docs.map((doc) {
        final uq = UserQuest.fromDoc(doc);
        return uq.copyWith(definition: globalDefs[doc.id]);
      }).toList()
        ..sort(_sortQuests);
    });
  }

  Stream<List<UserQuest>> watchActiveAndAvailableQuests({PillarType? pillar}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    var query = _firestore.collection('users').doc(uid).collection('quests').where(
      'status',
      whereIn: ['active', 'available'],
    );
    if (pillar != null) {
      query = query.where('pillar', isEqualTo: pillar.id);
    }
    return query.snapshots().asyncMap((snap) async {
      final globalDefs = await _fetchGlobalDefs(snap.docs.map((d) => d.id).toList());
      return snap.docs.map((doc) {
        final uq = UserQuest.fromDoc(doc);
        return uq.copyWith(definition: globalDefs[doc.id]);
      }).toList()
        ..sort(_sortQuests);
    });
  }

  Future<List<GlobalQuestDefinition>> fetchGlobalQuests({PillarType? pillar}) async {
    Query query = _firestore.collection('globalQuests').orderBy('sortOrder');
    if (pillar != null) {
      query = query.where('pillar', isEqualTo: pillar.id);
    }
    final snap = await query.get();
    return snap.docs.map(GlobalQuestDefinition.fromDoc).toList();
  }

  Future<void> activateQuest(String questId) async {
    final callable = _functions.httpsCallable('activateQuest');
    await callable.call({'questId': questId});
  }

  Future<QuestCompletionResult> completeQuest(String questId) async {
    final callable = _functions.httpsCallable('completeQuest');
    final result = await callable.call({'questId': questId});
    final data = result.data as Map<dynamic, dynamic>;
    return QuestCompletionResult(
      xpAwarded: (data['xpAwarded'] as num?)?.toInt() ?? 0,
      newLevel: (data['newLevel'] as num?)?.toInt() ?? 1,
      newTitle: data['newTitle'] as String? ?? '',
    );
  }

  Future<Map<String, GlobalQuestDefinition>> _fetchGlobalDefs(List<String> questIds) async {
    if (questIds.isEmpty) return {};
    final snaps = await Future.wait(
      questIds.map((id) => _firestore.collection('globalQuests').doc(id).get()),
    );
    final result = <String, GlobalQuestDefinition>{};
    for (final snap in snaps) {
      if (snap.exists) {
        result[snap.id] = GlobalQuestDefinition.fromDoc(snap);
      }
    }
    return result;
  }

  int _sortQuests(UserQuest a, UserQuest b) {
    const order = [QuestStatus.active, QuestStatus.available, QuestStatus.completed, QuestStatus.failed];
    final aIdx = order.indexOf(a.status);
    final bIdx = order.indexOf(b.status);
    if (aIdx != bIdx) return aIdx.compareTo(bIdx);
    return (a.definition?.sortOrder ?? 0).compareTo(b.definition?.sortOrder ?? 0);
  }
}
