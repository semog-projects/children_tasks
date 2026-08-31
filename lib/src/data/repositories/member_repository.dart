import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/member.dart';

class MemberRepository {
  MemberRepository(this._refs);

  final FirestoreRefs _refs;

  Stream<List<Member>> watchAll(String familyId) {
    return _refs
        .members(familyId)
        .orderBy('displayName')
        .snapshots()
        .map((snap) => snap.docs.map(Member.fromDoc).toList());
  }

  Stream<List<Member>> watchChildren(String familyId) {
    return _refs
        .members(familyId)
        .where('type', isEqualTo: MemberType.child.name)
        .snapshots()
        .map((snap) => snap.docs.map(Member.fromDoc).toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName)));
  }

  Future<String> add(String familyId, Member member) async {
    final ref = await _refs.members(familyId).add({
      ...member.toWriteData(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String familyId, Member member) {
    return _refs.members(familyId).doc(member.id).update({
      ...member.toWriteData(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove o membro. O histórico no `ledger` é preservado (append-only).
  Future<void> remove(String familyId, String memberId) {
    return _refs.members(familyId).doc(memberId).delete();
  }
}
