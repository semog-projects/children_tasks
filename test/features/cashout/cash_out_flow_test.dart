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

Future<String> _seedCashOut(
  FakeFirebaseFirestore db,
  String familyId,
  String memberId, {
  String status = 'requested',
  int points = 125,
  int amountCents = 200,
}) async {
  final ref =
      await db.collection('families').doc(familyId).collection('cashOuts').add({
    'memberId': memberId,
    'memberUid': 'uid-bia',
    'points': points,
    'amountCents': amountCents,
    'rateCents': 1.6,
    'status': status,
    'requestedAt': FieldValue.serverTimestamp(),
  });
  return ref.id;
}

Future<DocumentSnapshot<Map<String, dynamic>>> _childDoc(
    FakeFirebaseFirestore db, String familyId) async {
  final snap = await db
      .collection('families')
      .doc(familyId)
      .collection('members')
      .get();
  return snap.docs.single;
}

void main() {
  testWidgets('câmbio: converte reais em pontos e trava sem saldo',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = await _childDoc(app.db, familyId);
    await _seedBalance(app.db, familyId, child.id, 100); // 100 pts

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais ações de Bia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trocar por dinheiro'));
    await tester.pumpAndSettle();

    expect(find.text('100 pontos'), findsOneWidget); // saldo no StatCard

    // R$ 2,00 = 125 pontos, acima do saldo -> botão travado.
    await tester.enterText(
        find.widgetWithText(TextField, 'Valor em reais'), '200');
    await tester.pumpAndSettle();
    expect(find.text(r'R$ 2,00'), findsWidgets); // campo formatado como moeda
    expect(find.text('Custa 125 pontos'), findsOneWidget);
    expect(find.text('Saldo insuficiente.'), findsOneWidget);
    final blocked = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Pedir troca de 125 pontos'),
    );
    expect(blocked.onPressed, isNull);

    // R$ 1,00 -> snap para 65 pontos, dentro do saldo -> habilitado.
    await tester.enterText(
        find.widgetWithText(TextField, 'Valor em reais'), '100');
    await tester.pumpAndSettle();
    expect(find.text('Custa 65 pontos'), findsOneWidget);
    final ok = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Pedir troca de 65 pontos'),
    );
    expect(ok.onPressed, isNotNull);
  });

  testWidgets('câmbio: criança cancela o próprio pedido', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = await _childDoc(app.db, familyId);
    await _seedBalance(app.db, familyId, child.id, 500);
    final id = await _seedCashOut(app.db, familyId, child.id);

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais ações de Bia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trocar por dinheiro'));
    await tester.pumpAndSettle();

    expect(find.text('Aguardando aprovação'), findsOneWidget);
    // childMode: false pelo card do responsável -> sem botão "Cancelar".
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsNothing);

    // cancelamento direto pela camada de dados (a criança faria pela sua tela).
    await app.db
        .collection('families')
        .doc(familyId)
        .collection('cashOuts')
        .doc(id)
        .update({'status': 'canceled'});
    await tester.pumpAndSettle();
    expect(find.text('Cancelado'), findsOneWidget);
  });

  testWidgets('câmbio: responsável recusa um pedido com motivo', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = await _childDoc(app.db, familyId);
    final id = await _seedCashOut(app.db, familyId, child.id);

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Trocas por dinheiro'));
    await tester.pumpAndSettle();

    expect(find.text('Bia · R\$ 2,00'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Recusar'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Motivo (opcional)'), 'Semana que vem');
    await tester.tap(find.widgetWithText(FilledButton, 'Recusar'));
    await tester.pumpAndSettle();

    final doc = await app.db
        .collection('families')
        .doc(familyId)
        .collection('cashOuts')
        .doc(id)
        .get();
    expect(doc.data()!['status'], 'rejected');
    expect(doc.data()!['note'], 'Semana que vem');
  });

  testWidgets('câmbio: responsável marca um aprovado como pago', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = await _childDoc(app.db, familyId);
    final id = await _seedCashOut(app.db, familyId, child.id, status: 'approved');

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Trocas por dinheiro'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Marcar pago'));
    await tester.pumpAndSettle();

    final doc = await app.db
        .collection('families')
        .doc(familyId)
        .collection('cashOuts')
        .doc(id)
        .get();
    expect(doc.data()!['status'], 'paid');
  });
}
