import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/investment_lot.dart';
import '../models/investment_request.dart';

/// Leitura da poupança e as transições feitas pelo cliente (recusar, cancelar).
/// O aporte, o resgate e o cálculo do rendimento são das Cloud Functions
/// `requestInvestment` / `approveInvestment` (issue #73).
class InvestmentRepository {
  InvestmentRepository(this._refs);

  final FirestoreRefs _refs;

  // ---- lotes (posição) ----

  Stream<List<InvestmentLot>> watchLots(String familyId, String memberId) {
    return _refs
        .investmentLots(familyId, memberId)
        .snapshots()
        .map((snap) => snap.docs.map(InvestmentLot.fromDoc).toList());
  }

  /// Lotes da própria criança logada — filtra por `memberUid` (rules #34).
  Stream<List<InvestmentLot>> watchLotsByUid(
      String familyId, String memberId, String memberUid) {
    return _refs
        .investmentLots(familyId, memberId)
        .where('memberUid', isEqualTo: memberUid)
        .snapshots()
        .map((snap) => snap.docs.map(InvestmentLot.fromDoc).toList());
  }

  // ---- pedidos ----

  Stream<List<InvestmentRequest>> watchRequestsForMember(
      String familyId, String memberId) {
    return _sorted(
      _refs.investmentRequests(familyId).where('memberId', isEqualTo: memberId),
    );
  }

  Stream<List<InvestmentRequest>> watchRequestsByUid(
      String familyId, String memberUid) {
    return _sorted(
      _refs
          .investmentRequests(familyId)
          .where('memberUid', isEqualTo: memberUid),
    );
  }

  /// Fila do responsável: pedidos aguardando decisão.
  Stream<List<InvestmentRequest>> watchPending(String familyId) {
    return _sorted(
      _refs.investmentRequests(familyId).where('status',
          isEqualTo: InvestmentRequestStatus.requested.name),
    );
  }

  Stream<List<InvestmentRequest>> _sorted(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snap) =>
        snap.docs.map(InvestmentRequest.fromDoc).toList()
          ..sort((a, b) => (b.requestedAt ?? DateTime(0))
              .compareTo(a.requestedAt ?? DateTime(0))));
  }

  Future<void> reject(String familyId, String reqId, String uid,
      {String? note}) {
    return _refs.investmentRequests(familyId).doc(reqId).update({
      'status': InvestmentRequestStatus.rejected.name,
      'decidedByUid': uid,
      'decidedAt': FieldValue.serverTimestamp(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> cancel(String familyId, String reqId) {
    return _refs.investmentRequests(familyId).doc(reqId).update({
      'status': InvestmentRequestStatus.canceled.name,
    });
  }
}
