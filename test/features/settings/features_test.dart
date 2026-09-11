import 'package:childrentasks/src/data/models/family.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

Future<void> _openFeatures(WidgetTester tester) async {
  await openHomeMenu(tester, 'Família');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajustes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Funcionalidades'));
  await tester.pumpAndSettle();
}

void main() {
  test('Family: disabledFeatures round-trip', () {
    final db = FakeFirebaseFirestore();
    // vazio = tudo ligado
    const empty = Family(
        id: 'f', name: 'x', guardianUids: [], timezone: 'America/Sao_Paulo');
    expect(empty.isEnabled(AppFeature.cashOut), isTrue);

    final fam = empty.copyWith(
      disabledFeatures: {AppFeature.cashOut, AppFeature.investment},
    );
    expect(fam.isEnabled(AppFeature.cashOut), isFalse);
    expect(fam.isEnabled(AppFeature.rewards), isTrue);
    expect(fam.toUpdateData()['disabledFeatures'], ['cashOut', 'investment']);

    return db.collection('families').doc('f').set(fam.toUpdateData()).then((_) {
      return db.collection('families').doc('f').get().then((doc) {
        final back = Family.fromDoc(doc);
        expect(back.disabledFeatures, {AppFeature.cashOut, AppFeature.investment});
      });
    });
  });

  testWidgets('Funcionalidades: 4 switches, desligar persiste', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana');

    await pumpSettled(tester, app.widget);
    await _openFeatures(tester);

    expect(find.byType(SwitchListTile), findsNWidgets(4));

    await tester.tap(find.widgetWithText(
        SwitchListTile, 'Trocar pontos por dinheiro'));
    await tester.pumpAndSettle();

    final fam = await app.db.collection('families').doc(familyId).get();
    expect(fam.data()!['disabledFeatures'], ['cashOut']);
  });

  testWidgets('desligar câmbio esconde a entrada no menu do responsável',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    // já começa com câmbio desligado
    final fam = (await app.db
            .collection('families')
            .where('guardianUids', arrayContains: 'uid-ana')
            .get())
        .docs
        .single;
    await fam.reference.update({
      'disabledFeatures': ['cashOut', 'investment'],
    });

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Mais'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Trocas por dinheiro'), findsNothing);
    expect(find.textContaining('Poupança'), findsNothing);
    expect(find.text('Recompensas'), findsOneWidget); // essa segue ligada
  });

  testWidgets('desligar recompensas esconde o ícone na home da criança',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(
        initialUser: FakeAuthRepository.user(uid: 'uid-bia', name: 'Bia'),
      ),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = (await app.db
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get())
        .docs
        .single;
    await seedChildLogin(app.db, familyId, memberId: child.id, uid: 'uid-bia');
    await app.db.collection('families').doc(familyId).update({
      'disabledFeatures': ['rewards'],
    });

    await pumpSettled(tester, app.widget);

    expect(find.byTooltip('Recompensas'), findsNothing);
    expect(find.byTooltip('Trocar por dinheiro'), findsOneWidget);
    expect(find.byTooltip('Poupança'), findsOneWidget);
  });
}
