import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/ledger_entry.dart';

/// Leitura do ledger e cálculo de saldo. A escrita transacional (aprovação
/// credita, resgate debita) fica nas issues #9 e #12.
class LedgerRepository {
  LedgerRepository(this._refs);

  final FirestoreRefs _refs;

  Stream<List<LedgerEntry>> watchForMember(String familyId, String memberId) {
    return _refs
        .ledger(familyId)
        .where('memberId', isEqualTo: memberId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(LedgerEntry.fromDoc).toList());
  }

  /// Todo o ledger da família (mais recente primeiro). Para dashboard/histórico.
  Stream<List<LedgerEntry>> watchFamily(String familyId, {DateTime? since}) {
    Query<Map<String, dynamic>> query =
        _refs.ledger(familyId).orderBy('createdAt', descending: true);
    if (since != null) {
      query = query.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(since));
    }
    return query.snapshots().map((snap) => snap.docs.map(LedgerEntry.fromDoc).toList());
  }

  /// Saldo atual de uma criança (soma das entradas), pela visão do responsável.
  Stream<int> watchBalance(String familyId, String memberId) {
    return _sumPoints(
      _refs.ledger(familyId).where('memberId', isEqualTo: memberId),
    );
  }

  /// Saldo da própria criança logada — filtra por `memberUid` (rules #34).
  Stream<int> watchBalanceByUid(String familyId, String memberUid) {
    return _sumPoints(
      _refs.ledger(familyId).where('memberUid', isEqualTo: memberUid),
    );
  }

  Stream<int> _sumPoints(Query<Map<String, dynamic>> query) {
    return query.snapshots().map((snap) => snap.docs.fold<int>(
          0,
          (total, doc) => total + ((doc.data()['points'] as num?)?.toInt() ?? 0),
        ));
  }

  /// Lançamento avulso feito por um responsável (ajuste manual).
  Future<void> addAdjustment(
    String familyId, {
    required String memberId,
    required int points,
    required String createdByUid,
    String? note,
  }) {
    return _refs.ledger(familyId).add({
      ...LedgerEntry.createData(
        memberId: memberId,
        type: LedgerEntryType.adjustment,
        points: points,
        sourceType: LedgerSourceType.manual,
        note: note,
        createdByUid: createdByUid,
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
