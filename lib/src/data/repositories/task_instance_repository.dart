import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/task_instance.dart';

/// Leitura das ocorrências. A geração é feita por Cloud Function (#10);
/// a marcação/aprovação vem na #11.
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

  /// Ocorrências de um dia para uma criança.
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
}
