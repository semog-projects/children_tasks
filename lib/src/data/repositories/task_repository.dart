import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/task.dart';

class TaskRepository {
  TaskRepository(this._refs);

  final FirestoreRefs _refs;

  Stream<List<Task>> watchActive(String familyId) => _watch(familyId, active: true);

  Stream<List<Task>> watchArchived(String familyId) => _watch(familyId, active: false);

  Stream<List<Task>> _watch(String familyId, {required bool active}) {
    return _refs
        .tasks(familyId)
        .where('active', isEqualTo: active)
        .snapshots()
        .map((snap) => (snap.docs.map(Task.fromDoc).toList())
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())));
  }

  Future<Task?> get(String familyId, String taskId) async {
    final doc = await _refs.tasks(familyId).doc(taskId).get();
    return doc.exists ? Task.fromDoc(doc) : null;
  }

  Future<String> create(String familyId, Task task) async {
    final ref = await _refs.tasks(familyId).add({
      ...task.toWriteData(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String familyId, Task task) {
    return _refs.tasks(familyId).doc(task.id).update({
      ...task.toWriteData(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Arquiva/reativa. Arquivar não apaga — o histórico de ocorrências fica.
  Future<void> setActive(String familyId, String taskId, {required bool active}) {
    return _refs.tasks(familyId).doc(taskId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
