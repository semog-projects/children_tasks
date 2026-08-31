import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('onboarding cria a família e vai para a home', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await pumpSettled(tester, app.widget);

    await tester.tap(find.text('Criar uma família'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Família Nova');
    await tester.tap(find.text('Criar família'));
    await tester.pumpAndSettle();

    // Família criada -> o RoleGate troca a raiz pela home do responsável.
    expect(find.widgetWithText(AppBar, 'Família Nova'), findsOneWidget);

    final families = await app.db.collection('families').get();
    expect(families.docs.single.data()['name'], 'Família Nova');
    expect(families.docs.single.data()['guardianUids'], ['uid-ana']);
  });

  testWidgets('adiciona uma criança pela tela da família', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana');
    await pumpSettled(tester, app.widget);

    await tester.tap(find.byTooltip('Família'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Criança'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Léo');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Léo'), findsOneWidget);
    final members =
        await app.db.collection('families').doc(familyId).collection('members').get();
    expect(members.docs.single.data()['displayName'], 'Léo');
  });

  testWidgets('remove uma criança após confirmação', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    await pumpSettled(tester, app.widget);

    await tester.tap(find.byTooltip('Família'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
    await tester.pumpAndSettle();

    final members =
        await app.db.collection('families').doc(familyId).collection('members').get();
    expect(members.docs, isEmpty);
  });
}
