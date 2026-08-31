import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/redemption.dart';

/// Leitura dos resgates e a marcação de entrega. O resgate em si (débito
/// transacional de pontos) é feito pela Cloud Function `redeemReward`.
class RedemptionRepository {
  RedemptionRepository(this._refs);

  final FirestoreRefs _refs;

  Stream<List<Redemption>> watchAll(String familyId) {
    return _refs
        .redemptions(familyId)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Redemption.fromDoc).toList());
  }

  Stream<List<Redemption>> watchForMember(String familyId, String memberId) {
    return _sorted(
      _refs.redemptions(familyId).where('memberId', isEqualTo: memberId),
    );
  }

  /// Resgates da própria criança logada — filtra por `memberUid` (rules #34).
  Stream<List<Redemption>> watchForMemberUid(String familyId, String memberUid) {
    return _sorted(
      _refs.redemptions(familyId).where('memberUid', isEqualTo: memberUid),
    );
  }

  Stream<List<Redemption>> _sorted(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snap) =>
        (snap.docs.map(Redemption.fromDoc).toList())..sort((a, b) =>
            (b.requestedAt ?? DateTime(0)).compareTo(a.requestedAt ?? DateTime(0))));
  }

  Stream<List<Redemption>> watchPendingDelivery(String familyId) {
    return _refs
        .redemptions(familyId)
        .where('status', isEqualTo: RedemptionStatus.requested.name)
        .snapshots()
        .map((snap) => snap.docs.map(Redemption.fromDoc).toList());
  }

  Future<void> markDelivered(String familyId, String redemptionId, String uid) {
    return _refs.redemptions(familyId).doc(redemptionId).update({
      'status': RedemptionStatus.delivered.name,
      'deliveredAt': FieldValue.serverTimestamp(),
      'deliveredByUid': uid,
    });
  }
}
