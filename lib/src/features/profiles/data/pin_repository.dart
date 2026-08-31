import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import '../../../data/firestore_refs.dart';

/// PIN do responsável, guardado como hash + salt em `users/{uid}`.
///
/// SHA-256 com salt por usuário. Não é bcrypt, mas o hash só é acessível a
/// quem já está autenticado como aquele responsável (Security Rules), e o
/// papel do PIN é gatekeeper de "modo criança → modo responsável" dentro do
/// app. Tentativas são limitadas no cliente.
class PinRepository {
  PinRepository(this._refs);

  final FirestoreRefs _refs;

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  static String _newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<bool> hasPin(String uid) async {
    final doc = await _refs.user(uid).get();
    return (doc.data()?['pinHash'] as String?)?.isNotEmpty ?? false;
  }

  Future<void> setPin(String uid, String pin) async {
    final salt = _newSalt();
    await _refs.user(uid).set({
      'pinHash': _hash(pin, salt),
      'pinSalt': salt,
      'pinUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> verifyPin(String uid, String pin) async {
    final data = (await _refs.user(uid).get()).data();
    final hash = data?['pinHash'] as String?;
    final salt = data?['pinSalt'] as String?;
    if (hash == null || salt == null) return false;
    return _hash(pin, salt) == hash;
  }
}
