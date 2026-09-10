import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/cash_out.dart';

/// Leitura dos pedidos de câmbio e as transições feitas pelo cliente (recusar,
/// marcar pago, cancelar). O pedido em si e o débito transacional de pontos
/// são das Cloud Functions `requestCashOut` / `approveCashOut` (issue #66).
class CashOutRepository {
  CashOutRepository(this._refs);

  final FirestoreRefs _refs;

  Stream<List<CashOut>> watchForMember(String familyId, String memberId) {
    return _sorted(
      _refs.cashOuts(familyId).where('memberId', isEqualTo: memberId),
    );
  }

  /// Pedidos da própria criança logada — filtra por `memberUid` (rules #34).
  Stream<List<CashOut>> watchForMemberUid(String familyId, String memberUid) {
    return _sorted(
      _refs.cashOuts(familyId).where('memberUid', isEqualTo: memberUid),
    );
  }

  /// Fila do responsável: pedidos aguardando decisão ou pagamento.
  Stream<List<CashOut>> watchPending(String familyId) {
    return _sorted(
      _refs.cashOuts(familyId).where('status', whereIn: [
        CashOutStatus.requested.name,
        CashOutStatus.approved.name,
      ]),
    );
  }

  Stream<List<CashOut>> _sorted(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snap) =>
        snap.docs.map(CashOut.fromDoc).toList()
          ..sort((a, b) => (b.requestedAt ?? DateTime(0))
              .compareTo(a.requestedAt ?? DateTime(0))));
  }

  Future<void> reject(String familyId, String cashOutId, String uid,
      {String? note}) {
    return _refs.cashOuts(familyId).doc(cashOutId).update({
      'status': CashOutStatus.rejected.name,
      'decidedByUid': uid,
      'decidedAt': FieldValue.serverTimestamp(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> markPaid(String familyId, String cashOutId, String uid) {
    return _refs.cashOuts(familyId).doc(cashOutId).update({
      'status': CashOutStatus.paid.name,
      'paidByUid': uid,
      'paidAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancel(String familyId, String cashOutId) {
    return _refs.cashOuts(familyId).doc(cashOutId).update({
      'status': CashOutStatus.canceled.name,
    });
  }
}
