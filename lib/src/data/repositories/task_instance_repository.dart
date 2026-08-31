import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/task_instance.dart';

/// Leitura das ocorrências (geradas pela Cloud Function, #10) e as transições
/// de estado da marcação/aprovação (#11).
///
/// O crédito de pontos no `ledger` é feito por Cloud Function reagindo à
/// transição para `approved` — de forma idempotente. O cliente só muda o
/// `status` e os campos de revisão.
class TaskInstanceRepository {
  TaskInstanceRepository(this._refs);

  final FirestoreRefs _refs;

  /// Ocorrências de um dia (meia-noite UTC — ver `functions/src/shared/dates.ts`).
  Stream<List<TaskInstance>> watchForDate(String familyId, DateTime utcMidnight) {
    return _refs
        .taskInstances(familyId)
        .where('date', isEqualTo: Timestamp.fromDate(utcMidnight))
        .snapshots()
        .map((snap) => snap.docs.map(TaskInstance.fromDoc).toList());
  }

  /// Ocorrências de um dia para uma criança (visão do responsável, por
  /// `memberId`).
  Stream<List<TaskInstance>> watchForMemberAndDate(
    String familyId,
    String memberId,
    DateTime utcMidnight,
  ) {
    return _refs
        .taskInstances(familyId)
        .where('memberId', isEqualTo: memberId)
        .where('date', isEqualTo: Timestamp.fromDate(utcMidnight))
        .snapshots()
        .map((snap) => snap.docs.map(TaskInstance.fromDoc).toList());
  }

  /// Ocorrências de um dia da própria criança logada — filtra por `memberUid`
  /// (as rules da criança, issue #34, exigem esse filtro).
  Stream<List<TaskInstance>> watchForMemberUidAndDate(
    String familyId,
    String memberUid,
    DateTime utcMidnight,
  ) {
    return _refs
        .taskInstances(familyId)
        .where('memberUid', isEqualTo: memberUid)
        .where('date', isEqualTo: Timestamp.fromDate(utcMidnight))
        .snapshots()
        .map((snap) => snap.docs.map(TaskInstance.fromDoc).toList());
  }

  /// Fila de aprovação: ocorrências aguardando revisão do responsável.
  Stream<List<TaskInstance>> watchPendingApprovals(String familyId) {
    return _refs
        .taskInstances(familyId)
        .where('status', isEqualTo: TaskInstanceStatus.awaitingApproval.name)
        .snapshots()
        .map((snap) => (snap.docs.map(TaskInstance.fromDoc).toList())
          ..sort((a, b) => (a.completedAt ?? a.date).compareTo(b.completedAt ?? b.date)));
  }

  DocumentReference<Map<String, dynamic>> _doc(String familyId, String instanceId) =>
      _refs.taskInstances(familyId).doc(instanceId);

  /// A criança marcou a tarefa como feita.
  /// Vai para `awaitingApproval`, ou direto para `approved` se a tarefa não
  /// exige aprovação (aí a Function credita os pontos).
  Future<void> markDone(String familyId, TaskInstance instance) {
    final next = instance.requiresApproval
        ? TaskInstanceStatus.awaitingApproval
        : TaskInstanceStatus.approved;
    return _doc(familyId, instance.id).update({
      'status': next.name,
      'completedAt': FieldValue.serverTimestamp(),
      // Só toca `rejectionReason` se havia um (mantém o diff mínimo — as
      // rules da criança só liberam status/completedAt/rejectionReason/updatedAt).
      if (instance.rejectionReason != null) 'rejectionReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// O responsável aprovou. A Function credita os pontos no `ledger`.
  Future<void> approve(String familyId, String instanceId, String reviewerUid) {
    return _doc(familyId, instanceId).update({
      'status': TaskInstanceStatus.approved.name,
      'reviewedByUid': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// O responsável rejeitou: volta para `pending` com o motivo.
  Future<void> reject(
    String familyId,
    String instanceId,
    String reviewerUid, {
    String? reason,
  }) {
    return _doc(familyId, instanceId).update({
      'status': TaskInstanceStatus.pending.name,
      'reviewedByUid': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason,
      'completedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
