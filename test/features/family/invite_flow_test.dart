import 'package:childrentasks/src/features/family/data/invites_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_invites_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('responsável gera um código de convite para a criança',
      (tester) async {
    final invites = FakeInvitesRepository(
      invite: FamilyInvite(
        code: 'ABCD2345',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      ),
    );
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
      invites: invites,
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    await pumpSettled(tester, app.widget);

    await tester.tap(find.byTooltip('Família'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bia'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Gerar convite'));
    await tester.tap(find.text('Gerar convite'));
    await tester.pumpAndSettle();

    expect(find.text('ABCD2345'), findsOneWidget);
    expect(invites.createdInvites.single.familyId, familyId);
  });

  testWidgets('criança entra com um código de convite', (tester) async {
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

    // O fake aplica o vínculo no Firestore fake, como a Function faria.
    final invites = FakeInvitesRepository(
      onAccept: (_) =>
          seedChildLogin(db, familyId, memberId: childId, uid: 'uid-bia'),
    );
    final app = await buildTestApp(
      auth: FakeAuthRepository(
        initialUser: FakeAuthRepository.user(
          name: 'Bia',
          email: 'bia@example.com',
          uid: 'uid-bia',
        ),
      ),
      db: db,
      invites: invites,
    );
    await pumpSettled(tester, app.widget);

    expect(find.text('Você ainda não faz parte de uma família'), findsOneWidget);

    await tester.tap(find.text('Tenho um código de convite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'TESTCODE');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(invites.acceptedCodes, ['TESTCODE']);
    expect(find.text('Olá, Bia!'), findsOneWidget);
  });

  testWidgets('código inválido mostra erro e não sai da tela', (tester) async {
    final invites = FakeInvitesRepository(
      onAccept: (_) => throw const InviteException('Código não encontrado.'),
    );
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
      invites: invites,
    );
    await pumpSettled(tester, app.widget);

    await tester.tap(find.text('Tenho um código de convite'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NOPE1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Código não encontrado.'), findsOneWidget);
    expect(find.text('Criar uma família'), findsOneWidget); // ainda na welcome
  });
}
