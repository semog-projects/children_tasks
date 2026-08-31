import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_refs.dart';
import '../models/reward.dart';

class RewardRepository {
  RewardRepository(this._refs);

  final FirestoreRefs _refs;

  Stream<List<Reward>> watchAll(String familyId) {
    return _refs
        .rewards(familyId)
        .snapshots()
        .map((snap) => snap.docs.map(Reward.fromDoc).toList());
  }

  Stream<List<Reward>> watchActive(String familyId) {
    return _refs
        .rewards(familyId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(Reward.fromDoc).toList());
  }

  Future<Reward?> get(String familyId, String rewardId) async {
    final doc = await _refs.rewards(familyId).doc(rewardId).get();
    return doc.exists ? Reward.fromDoc(doc) : null;
  }

  Future<String> create(String familyId, Reward reward) async {
    final ref = await _refs.rewards(familyId).add({
      ...reward.toWriteData(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> update(String familyId, Reward reward) {
    return _refs.rewards(familyId).doc(reward.id).update({
      ...reward.toWriteData(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
