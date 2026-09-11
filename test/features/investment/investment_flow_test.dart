import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

Future<DocumentSnapshot<Map<String, dynamic>>> _child(
    FakeFirebaseFirestore db, String familyId) async {
  final snap = await db
      .collection('families')
      .doc(familyId)
      .collection('members')
      .get();
  return snap.docs.single;
}

Future<void> _seedLot(
  FakeFirebaseFirestore db,
  String familyId,
  String memberId, {
  required int points,
  required Duration age,
}) async {
  await db
      .collection('families')
      .doc(familyId)
      .collection('investments')
      .doc(memberId)
      .collection('lots')
      .add({
    'points': points,
    'memberUid': 'uid-bia',
    'createdAt': Timestamp.fromDate(DateTime.now().subtract(age)),
  });
}

Future<String> _seedRequest(
  FakeFirebaseFirestore db,
  String familyId,
  String memberId, {
  String kind = 'deposit',
  int points = 100,
  String status = 'requested',
}) async {
  final ref = await db
      .collection('families')
      .doc(familyId)
      .collection('investmentRequests')
      .add({
    'memberId': memberId,
    'memberUid': 'uid-bia',
    'kind': kind,
    if (kind == 'deposit') 'points': points,
    'status': status,
    'requestedAt': FieldValue.serverTimestamp(),
  });
  return ref.id;
}

Future<void> _openInvest(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mais ações de Bia'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Investir pontos'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('poupança: sem lotes o resgate fica travado', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);

    await pumpSettled(tester, app.widget);
    await _openInvest(tester);

    expect(find.text('0 pontos'), findsOneWidget); // investido
    final withdraw = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Resgatar tudo'),
    );
    expect(withdraw.onPressed, isNull);
    // seção educativa presente
    expect(find.text('Como a poupança funciona'), findsOneWidget);
  });

  testWidgets('poupança: mostra valor rendendo e aviso de carência',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = await _child(app.db, familyId);
    // 1000 pts há 40 dias (fora da carência) rendendo 2%/semana -> vale bem mais
    await _seedLot(app.db, familyId, child.id,
        points: 1000, age: const Duration(days: 40));
    await _seedLot(app.db, familyId, child.id,
        points: 200, age: const Duration(days: 2)); // dentro da carência

    await pumpSettled(tester, app.widget);
    await _openInvest(tester);

    expect(find.text('1200 pontos'), findsOneWidget); // principal
    expect(find.textContaining('de rendimento'), findsOneWidget);
    expect(find.textContaining('Rendimento cheio a partir de'), findsOneWidget);

    final withdraw = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Resgatar tudo'),
    );
    expect(withdraw.onPressed, isNotNull);
  });

  testWidgets('poupança: responsável recusa um pedido de aporte',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = await _child(app.db, familyId);
    final id = await _seedRequest(app.db, familyId, child.id, points: 80);

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Poupança'));
    await tester.pumpAndSettle();

    expect(find.text('Bia quer investir 80 pontos'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Recusar'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Motivo (opcional)'), 'Junte mais');
    await tester.tap(find.widgetWithText(FilledButton, 'Recusar'));
    await tester.pumpAndSettle();

    final doc = await app.db
        .collection('families')
        .doc(familyId)
        .collection('investmentRequests')
        .doc(id)
        .get();
    expect(doc.data()!['status'], 'rejected');
    expect(doc.data()!['note'], 'Junte mais');
  });

  testWidgets('poupança: responsável edita a taxa', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Poupança'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('por semana'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Rendimento por semana'), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    final fam = await app.db.collection('families').doc(familyId).get();
    expect(fam.data()!['investmentWeeklyRatePct'], 5);
  });
}
