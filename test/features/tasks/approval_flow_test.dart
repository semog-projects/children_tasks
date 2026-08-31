import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

Timestamp _today() {
  final now = DateTime.now();
  return Timestamp.fromDate(DateTime.utc(now.year, now.month, now.day));
}

Future<String> _seedInstance(
  FakeFirebaseFirestore db, {
  required String familyId,
  required String memberId,
  String status = 'pending',
  bool requiresApproval = true,
  String? rejectionReason,
}) async {
  final ref = await db
      .collection('families')
      .doc(familyId)
      .collection('taskInstances')
      .add({
    'taskId': 't1',
    'memberId': memberId,
    'date': _today(),
    'status': status,
    'titleSnapshot': 'Arrumar a cama',
    'pointsSnapshot': 10,
    'requiresApproval': requiresApproval,
    'rejectionReason': rejectionReason,
  });
  return ref.id;
}

Future<Map<String, dynamic>> _instance(FakeFirebaseFirestore db, String familyId, String id) async {
  final doc = await db
      .collection('families')
      .doc(familyId)
      .collection('taskInstances')
      .doc(id)
      .get();
  return doc.data()!;
}

void main() {
  testWidgets('criança marca feita -> aguardando; responsável aprova', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = (await app.db
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get())
        .docs
        .single;
    final instanceId = await _seedInstance(app.db, familyId: familyId, memberId: child.id);
    await pumpSettled(tester, app.widget);

    await tester.tap(find.text('Tarefas de hoje'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feita'));
    await tester.pumpAndSettle();
    expect((await _instance(app.db, familyId, instanceId))['status'], 'awaitingApproval');

    await tester.tap(find.byTooltip('Aprovar'));
    await tester.pumpAndSettle();
    final approved = await _instance(app.db, familyId, instanceId);
    expect(approved['status'], 'approved');
    expect(approved['reviewedByUid'], 'uid-ana');
  });

  testWidgets('tarefa sem aprovação vai direto para approved', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = (await app.db
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get())
        .docs
        .single;
    final instanceId = await _seedInstance(
      app.db,
      familyId: familyId,
      memberId: child.id,
      requiresApproval: false,
    );
    await pumpSettled(tester, app.widget);

    await tester.tap(find.text('Tarefas de hoje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feita'));
    await tester.pumpAndSettle();

    expect((await _instance(app.db, familyId, instanceId))['status'], 'approved');
  });

  testWidgets('rejeição volta para pendente com o motivo', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = (await app.db
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get())
        .docs
        .single;
    final instanceId = await _seedInstance(
      app.db,
      familyId: familyId,
      memberId: child.id,
      status: 'awaitingApproval',
    );
    await pumpSettled(tester, app.widget);

    await tester.tap(find.byTooltip('Aprovações'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rejeitar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ainda bagunçada');
    await tester.tap(find.widgetWithText(FilledButton, 'Rejeitar'));
    await tester.pumpAndSettle();

    final rejected = await _instance(app.db, familyId, instanceId);
    expect(rejected['status'], 'pending');
    expect(rejected['rejectionReason'], 'ainda bagunçada');
  });
}
