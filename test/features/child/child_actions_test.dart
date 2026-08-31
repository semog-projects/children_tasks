import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

DateTime _todayUtc() {
  final n = DateTime.now();
  return DateTime.utc(n.year, n.month, n.day);
}

Future<({FakeFirebaseFirestore db, Widget widget, String childId})> _childApp() async {
  final db = FakeFirebaseFirestore();
  final familyId = await seedFamily(db, uid: 'uid-ana', childNames: ['Bia']);
  final childId = (await db
          .collection('families')
          .doc(familyId)
          .collection('members')
          .get())
      .docs
      .single
      .id;
  await seedChildLogin(db, familyId, memberId: childId, uid: 'uid-bia');
  final app = await buildTestApp(
    auth: FakeAuthRepository(
      initialUser: FakeAuthRepository.user(
        name: 'Bia',
        email: 'bia@example.com',
        uid: 'uid-bia',
      ),
    ),
    db: db,
  );
  return (db: db, widget: app.widget, childId: childId);
}

void main() {
  testWidgets('criança marca a própria tarefa como feita', (tester) async {
    final app = await _childApp();
    final familyId =
        (await app.db.collection('families').get()).docs.single.id;
    final instance = await app.db
        .collection('families')
        .doc(familyId)
        .collection('taskInstances')
        .add({
      'taskId': 't1',
      'memberId': app.childId,
      'memberUid': 'uid-bia',
      'date': Timestamp.fromDate(_todayUtc()),
      'status': 'pending',
      'titleSnapshot': 'Arrumar a cama',
      'pointsSnapshot': 10,
      'requiresApproval': true,
    });

    await pumpSettled(tester, app.widget);

    expect(find.text('Arrumar a cama'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Feita'));
    await tester.pumpAndSettle();

    final doc = await app.db
        .collection('families')
        .doc(familyId)
        .collection('taskInstances')
        .doc(instance.id)
        .get();
    expect(doc.data()!['status'], 'awaitingApproval');
    expect(doc.data()!['completedAt'], isNotNull);
  });

  testWidgets('criança ajusta uma preferência de notificação', (tester) async {
    final app = await _childApp();
    await pumpSettled(tester, app.widget);

    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Recompensa entregue'),
    );
    await tester.pumpAndSettle();

    final user = await app.db.collection('users').doc('uid-bia').get();
    expect((user.data()!['notif'] as Map)['rewardDelivered'], false);
    expect((user.data()!['notif'] as Map)['taskApproved'], true);
  });
}
