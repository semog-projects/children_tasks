import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/family.dart';

/// CRUD de famílias. Membros ficam em [MemberRepository].
class FamilyRepository {
  FamilyRepository(this._refs);

  final FirestoreRefs _refs;

  /// Famílias em que [uid] é responsável.
  Stream<List<Family>> watchForGuardian(String uid) {
    return _refs.families
        .where('guardianUids', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs.map(Family.fromDoc).toList());
  }

  Stream<Family?> watch(String familyId) {
    return _refs
        .family(familyId)
        .snapshots()
        .map((doc) => doc.exists ? Family.fromDoc(doc) : null);
  }

  Future<Family?> get(String familyId) async {
    final doc = await _refs.family(familyId).get();
    return doc.exists ? Family.fromDoc(doc) : null;
  }

  /// Cria a família com [creatorUid] como primeiro responsável. Retorna o id.
  Future<String> create(Family family, {required String creatorUid}) async {
    final ref = await _refs.families.add({
      ...family.toCreateData(creatorUid),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(Family family) {
    return _refs.family(family.id).update({
      ...family.toUpdateData(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
