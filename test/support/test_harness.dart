import 'package:childrentasks/src/app/children_tasks_app.dart';
import 'package:childrentasks/src/app/firebase/firebase_bootstrap.dart';
import 'package:childrentasks/src/app/firebase/firebase_providers.dart';
import 'package:childrentasks/src/data/firestore_refs.dart';
import 'package:childrentasks/src/features/auth/application/auth_providers.dart';
import 'package:childrentasks/src/features/profiles/application/profile_providers.dart';
import 'package:childrentasks/src/features/profiles/data/pin_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_auth_repository.dart';

/// Semeia uma família com [uid] como responsável e as crianças informadas.
/// Também grava um PIN para o responsável (senão o app pede para criar um).
Future<String> seedFamily(
  FakeFirebaseFirestore db, {
  required String uid,
  String name = 'Família Teste',
  List<String> childNames = const [],
  bool withPin = true,
}) async {
  if (withPin) {
    await db.collection('users').doc(uid).set({
      'pinHash': 'seeded-hash',
      'pinSalt': 'seeded-salt',
    });
  }
  final family = await db.collection('families').add({
    'name': name,
    'guardianUids': [uid],
    'guardians': [
      {'uid': uid, 'displayName': 'Ana'},
    ],
    'timezone': 'America/Sao_Paulo',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  for (final childName in childNames) {
    await family.collection('members').add({
      'type': 'child',
      'displayName': childName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  return family.id;
}

/// Monta o app com o backend fake. Retorna o Firestore fake para inspeção/seed.
///
/// [prefs] alimenta o `sharedPreferencesProvider` — passe
/// `{'activeProfile': 'guardian'}` para começar já no modo responsável.
Future<({Widget widget, FakeFirebaseFirestore db})> buildTestApp({
  FirebaseInitStatus firebase = FirebaseInitStatus.ready,
  FakeAuthRepository? auth,
  FakeFirebaseFirestore? db,
  Map<String, Object> prefs = const {'activeProfile': 'guardian'},
}) async {
  final firestore = db ?? FakeFirebaseFirestore();
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();

  final widget = ProviderScope(
    overrides: [
      firebaseInitStatusProvider.overrideWithValue(firebase),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      firestoreProvider.overrideWithValue(firestore),
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    ],
    child: const ChildrenTasksApp(),
  );
  return (widget: widget, db: firestore);
}

/// Grava um PIN real (hash verificável) para [uid].
Future<void> seedRealPin(FakeFirebaseFirestore db, String uid, String pin) {
  return PinRepository(FirestoreRefs(db)).setPin(uid, pin);
}

Future<void> pumpSettled(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}
