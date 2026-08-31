import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_bootstrap.dart';

/// Status da inicialização do Firebase, resolvido em `main()` e injetado via
/// override no `ProviderScope`. Sobrescrito nos testes.
final firebaseInitStatusProvider = Provider<FirebaseInitStatus>((ref) {
  throw UnimplementedError('firebaseInitStatusProvider deve ser sobrescrito em main()/testes');
});

/// `true` quando o backend está disponível (flutterfire configurado).
final firebaseReadyProvider = Provider<bool>((ref) {
  return ref.watch(firebaseInitStatusProvider) == FirebaseInitStatus.ready;
});

/// Instância do Firebase Auth. Só use quando [firebaseReadyProvider] for `true`.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Instância do Cloud Firestore. Só use quando [firebaseReadyProvider] for `true`.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
