import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('responsável de uma família cai na home do responsável',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', name: 'Família Silva');
    await pumpSettled(tester, app.widget);

    expect(find.byTooltip('Aprovações'), findsOneWidget);
    expect(find.byTooltip('Mais'), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Família Silva'), findsOneWidget);
  });

  testWidgets('criança logada cai no modo criança, sem telas de responsável',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(
        initialUser: FakeAuthRepository.user(
          name: 'Bia',
          email: 'bia@example.com',
          uid: 'uid-bia',
        ),
      ),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = (await app.db
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get())
        .docs
        .single;
    await seedChildLogin(app.db, familyId, memberId: child.id, uid: 'uid-bia');

    await pumpSettled(tester, app.widget);

    expect(find.text('Olá, Bia!'), findsOneWidget);
    expect(find.byTooltip('Família'), findsNothing);
    expect(find.byTooltip('Aprovações'), findsNothing);
    expect(find.byTooltip('Definição de tarefas'), findsNothing);
    expect(find.byTooltip('Sair da conta'), findsOneWidget);
  });

  testWidgets('usuário sem família vê a tela de boas-vindas', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await pumpSettled(tester, app.widget);

    expect(find.text('Você ainda não faz parte de uma família'), findsOneWidget);
    expect(find.text('Criar uma família'), findsOneWidget);
    expect(find.text('Tenho um código de convite'), findsOneWidget);
  });

  testWidgets('criança sai da conta e volta ao login', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(
        initialUser: FakeAuthRepository.user(
          name: 'Bia',
          email: 'bia@example.com',
          uid: 'uid-bia',
        ),
      ),
    );
    final familyId =
        await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = (await app.db
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get())
        .docs
        .single;
    await seedChildLogin(app.db, familyId, memberId: child.id, uid: 'uid-bia');

    await pumpSettled(tester, app.widget);
    await tester.tap(find.byTooltip('Sair da conta'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar com Google'), findsOneWidget);
  });
}
