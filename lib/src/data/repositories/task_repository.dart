import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/task.dart';

class TaskRepository {
  TaskRepository(this._refs);

  final FirestoreRefs _refs;

  Stream<List<Task>> watchActive(String familyId) {
    return _refs
        .tasks(familyId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Task.fromDoc).toList());
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

  /// Arquiva (não apaga — o histórico de ocorrências continua válido).
  Future<void> archive(String familyId, String taskId) {
    return _refs.tasks(familyId).doc(taskId).update({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
