import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PartnerService {
  final _functions = FirebaseFunctions.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Linking ──────────────────────────────────────────────────────────────

  /// Generate a one-time invite code stored in Firestore.
  Future<String> generateInviteCode() async {
    final uid = _uid!;
    final code = uid.substring(0, 8).toUpperCase();
    await _firestore.collection('inviteCodes').doc(code).set({
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'used': false,
    });
    return code;
  }

  /// Link to a partner via their invite code.
  Future<void> linkPartner(String code) async {
    final callable = _functions.httpsCallable('linkAccountabilityPartner');
    await callable.call({'inviteCode': code.toUpperCase()});
  }

  Future<void> unlinkPartner() async {
    final callable = _functions.httpsCallable('unlinkAccountabilityPartner');
    await callable.call({});
  }

  // ── Extension Requests ───────────────────────────────────────────────────

  /// Send a 10-minute extension request to the linked partner.
  Future<String> requestExtension() async {
    final callable = _functions.httpsCallable('requestExtension');
    final result = await callable.call({});
    return result.data['requestId'] as String;
  }

  /// Listen for incoming extension requests directed at this user (as a partner).
  Stream<List<ExtensionRequest>> get incomingRequests {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('extensionRequests')
        .where('partnerId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExtensionRequest.fromDoc(doc))
            .where((req) => req.expiresAt.isAfter(DateTime.now()))
            .toList());
  }

  /// Approve or deny an extension request.
  Future<void> respondToRequest(String requestId, bool approved) async {
    await _firestore.collection('extensionRequests').doc(requestId).update({
      'status': approved ? 'approved' : 'denied',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream for the requesting user to wait for partner response.
  Stream<String?> watchRequestStatus(String requestId) {
    return _firestore
        .collection('extensionRequests')
        .doc(requestId)
        .snapshots()
        .map((doc) => doc.data()?['status'] as String?);
  }
}

class ExtensionRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final DateTime expiresAt;

  ExtensionRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.expiresAt,
  });

  factory ExtensionRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExtensionRequest(
      id: doc.id,
      requesterId: data['requesterId'] as String,
      requesterName: data['requesterName'] as String? ?? 'Your partner',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (data['expiresAt'] as int?) ?? 0,
      ),
    );
  }
}
