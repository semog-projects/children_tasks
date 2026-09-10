import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('responsável desconta pontos com motivo pelo card da criança',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);

    await pumpSettled(tester, app.widget);

    await tester.tap(find.byTooltip('Mais ações de Bia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustar pontos'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Pontos'), '15');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo'),
      'Não guardou os brinquedos',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    final entries = await app.db
        .collection('families')
        .doc(familyId)
        .collection('ledger')
        .get();
    final entry = entries.docs.single.data();
    expect(entry['points'], -15);
    expect(entry['type'], 'adjustment');
    expect(entry['sourceType'], 'manual');
    expect(entry['note'], 'Não guardou os brinquedos');
  });

  testWidgets('o diálogo exige valor e motivo', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais ações de Bia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustar pontos'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe um número maior que zero.'), findsOneWidget);
    expect(find.text('O motivo é obrigatório.'), findsOneWidget);
  });

  testWidgets('o diálogo não estoura com o teclado aberto', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais ações de Bia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustar pontos'));
    await tester.pumpAndSettle();

    // Simula o teclado virtual subindo: sem SingleChildScrollView o conteúdo
    // do AlertDialog dava "BOTTOM OVERFLOWED" (pump lançaria a exceção).
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(TextFormField, 'Pontos'), findsOneWidget);
  });
}
