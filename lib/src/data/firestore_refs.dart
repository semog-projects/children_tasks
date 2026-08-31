import 'package:cloud_firestore/cloud_firestore.dart';

/// Caminhos e coleções do Firestore num único lugar.
/// Ver `docs/data-model.md`.
class FirestoreRefs {
  FirestoreRefs(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get users => _db.collection('users');
  DocumentReference<Map<String, dynamic>> user(String uid) => users.doc(uid);

  CollectionReference<Map<String, dynamic>> fcmTokens(String uid) =>
      user(uid).collection('fcmTokens');

  CollectionReference<Map<String, dynamic>> get families => _db.collection('families');
  DocumentReference<Map<String, dynamic>> family(String familyId) => families.doc(familyId);

  CollectionReference<Map<String, dynamic>> members(String familyId) =>
      family(familyId).collection('members');

  CollectionReference<Map<String, dynamic>> tasks(String familyId) =>
      family(familyId).collection('tasks');

  CollectionReference<Map<String, dynamic>> taskInstances(String familyId) =>
      family(familyId).collection('taskInstances');

  CollectionReference<Map<String, dynamic>> rewards(String familyId) =>
      family(familyId).collection('rewards');

  CollectionReference<Map<String, dynamic>> redemptions(String familyId) =>
      family(familyId).collection('redemptions');

  CollectionReference<Map<String, dynamic>> ledger(String familyId) =>
      family(familyId).collection('ledger');
}
