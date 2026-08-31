import 'package:childrentasks/src/app/children_tasks_app.dart';
import 'package:childrentasks/src/app/firebase/firebase_bootstrap.dart';
import 'package:childrentasks/src/app/firebase/firebase_providers.dart';
import 'package:childrentasks/src/features/auth/application/auth_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

/// Semeia uma família com [uid] como responsável e as crianças informadas.
Future<String> seedFamily(
  FakeFirebaseFirestore db, {
  required String uid,
  String name = 'Família Teste',
  List<String> childNames = const [],
}) async {
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
({Widget widget, FakeFirebaseFirestore db}) buildTestApp({
  FirebaseInitStatus firebase = FirebaseInitStatus.ready,
  FakeAuthRepository? auth,
  FakeFirebaseFirestore? db,
}) {
  final firestore = db ?? FakeFirebaseFirestore();
  final widget = ProviderScope(
    overrides: [
      firebaseInitStatusProvider.overrideWithValue(firebase),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      firestoreProvider.overrideWithValue(firestore),
    ],
    child: const ChildrenTasksApp(),
  );
  return (widget: widget, db: firestore);
}

Future<void> pumpSettled(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}
