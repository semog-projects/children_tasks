import 'package:childrentasks/src/app/children_tasks_app.dart';
import 'package:childrentasks/src/app/firebase/firebase_bootstrap.dart';
import 'package:childrentasks/src/app/firebase/firebase_providers.dart';
import 'package:childrentasks/src/common/sync/sync_providers.dart';
import 'package:childrentasks/src/features/auth/application/auth_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

/// Semeia uma família com [uid] como responsável e as crianças informadas.
/// Retorna o id da família.
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

/// Vincula [uid] à criança [memberId] (login próprio da criança — issue #33).
Future<void> seedChildLogin(
  FakeFirebaseFirestore db,
  String familyId, {
  required String memberId,
  required String uid,
}) async {
  final family = db.collection('families').doc(familyId);
  await family
      .collection('members')
      .doc(memberId)
      .set({'linkedUid': uid}, SetOptions(merge: true));
  await family.set(
    {'childUids': FieldValue.arrayUnion([uid])},
    SetOptions(merge: true),
  );
}

/// Monta o app com o backend fake. Retorna o Firestore fake para inspeção/seed.
Future<({Widget widget, FakeFirebaseFirestore db})> buildTestApp({
  FirebaseInitStatus firebase = FirebaseInitStatus.ready,
  FakeAuthRepository? auth,
  FakeFirebaseFirestore? db,
  bool online = true,
}) async {
  final firestore = db ?? FakeFirebaseFirestore();

  final widget = ProviderScope(
    overrides: [
      firebaseInitStatusProvider.overrideWithValue(firebase),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      firestoreProvider.overrideWithValue(firestore),
      connectivityProvider.overrideWith((ref) => Stream.value(online)),
      pendingWritesProvider.overrideWith((ref) => Stream.value(false)),
    ],
    child: const ChildrenTasksApp(),
  );
  return (widget: widget, db: firestore);
}

Future<void> pumpSettled(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}
