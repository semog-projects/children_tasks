import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

Future<void> _seedBalance(
  FakeFirebaseFirestore db,
  String familyId,
  String memberId,
  int points,
) async {
  await db.collection('families').doc(familyId).collection('ledger').add({
    'memberId': memberId,
    'type': 'earn',
    'points': points,
    'sourceType': 'taskInstance',
    'createdByUid': 'system',
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<String> _seedReward(
  FakeFirebaseFirestore db,
  String familyId, {
  String title = 'Sorvete',
  int cost = 50,
  bool active = true,
}) async {
  final ref = await db.collection('families').doc(familyId).collection('rewards').add({
    'title': title,
    'cost': cost,
    'active': active,
    'stock': null,
  });
  return ref.id;
}

void main() {
  testWidgets('responsável cria uma recompensa', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    await pumpSettled(tester, app.widget);

    await openHomeMenu(tester, 'Recompensas');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recompensa'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Cinema');
    await tester.enterText(find.widgetWithText(TextFormField, 'Custo em pontos'), '120');
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Cinema'), findsOneWidget);
    final rewards =
        await app.db.collection('families').doc(familyId).collection('rewards').get();
    expect(rewards.docs.single.data()['cost'], 120);
  });

  testWidgets('catálogo habilita resgate só com saldo', (tester) async {
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
    await _seedReward(app.db, familyId, cost: 50);
    await _seedBalance(app.db, familyId, child.id, 30);

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Recompensas de Bia'));
    await tester.pumpAndSettle();

    expect(find.text('30 pontos'), findsOneWidget);
    final redeemBtn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Resgatar'),
    );
    expect(redeemBtn.onPressed, isNull); // saldo insuficiente

    // sobe o saldo
    await _seedBalance(app.db, familyId, child.id, 40);
    await tester.pumpAndSettle();
    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Resgatar'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('responsável marca resgate como entregue', (tester) async {
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
    final redemption = await app.db
        .collection('families')
        .doc(familyId)
        .collection('redemptions')
        .add({
      'rewardId': 'r1',
      'memberId': child.id,
      'rewardTitleSnapshot': 'Sorvete',
      'cost': 50,
      'status': 'requested',
      'requestedAt': FieldValue.serverTimestamp(),
    });

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Recompensas de Bia'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Entregar'));
    await tester.pumpAndSettle();

    final doc = await app.db
        .collection('families')
        .doc(familyId)
        .collection('redemptions')
        .doc(redemption.id)
        .get();
    expect(doc.data()!['status'], 'delivered');
  });
}
