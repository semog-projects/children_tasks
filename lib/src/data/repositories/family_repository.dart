import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/family.dart';

/// CRUD de famílias. Membros (crianças) ficam em [MemberRepository].
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

  /// Famílias em que [uid] é uma criança com login próprio vinculado
  /// (`family.childUids`, gerido pela Function do vínculo — issue #33).
  Stream<List<Family>> watchForChild(String uid) {
    return _refs.families
        .where('childUids', arrayContains: uid)
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

  /// Cria a família com [creator] como primeiro responsável. Retorna o id.
  Future<String> create(Family family, {required GuardianRef creator}) async {
    final ref = await _refs.families.add({
      ...family.toCreateData(creator),
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

  /// Atualiza o nome/foto do responsável [me] no doc da família, se estiver
  /// desatualizado. Chamado quando o responsável abre o app.
  Future<void> healGuardianProfile(Family family, GuardianRef me) async {
    final current = family.guardianFor(me.uid);
    if (current != null &&
        current.displayName == me.displayName &&
        current.photoUrl == me.photoUrl) {
      return;
    }
    final updated = [
      for (final g in family.guardians)
        if (g.uid == me.uid) me else g,
      if (current == null) me,
    ];
    await _refs.family(family.id).update({
      'guardians': updated.map((g) => g.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
