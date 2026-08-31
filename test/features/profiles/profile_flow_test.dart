import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('sem PIN: obriga a criar um', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', withPin: false);
    await pumpSettled(tester, app.widget);

    expect(find.text('Criar PIN'), findsOneWidget);

    final field = find.byType(TextField);
    await tester.enterText(field, '1234');
    await tester.pumpAndSettle();
    await tester.enterText(field, '1234'); // confirmação
    await tester.pumpAndSettle();

    // Depois de criar, entra como responsável.
    expect(find.byTooltip('Trocar de perfil'), findsOneWidget);
    final user = await app.db.collection('users').doc('uid-ana').get();
    expect((user.data()!['pinHash'] as String).isNotEmpty, isTrue);
  });

  testWidgets('seletor de perfil: entrar no modo criança', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
      prefs: const {'activeProfile': 'none'},
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    await pumpSettled(tester, app.widget);

    expect(find.text('Quem é você?'), findsOneWidget);

    await tester.tap(find.text('Bia'));
    await tester.pumpAndSettle();

    // modo criança: sem telas de responsável
    expect(find.text('Olá, Bia!'), findsOneWidget);
    expect(find.byTooltip('Família'), findsNothing);
    expect(find.byTooltip('Aprovações'), findsNothing);
    expect(find.byTooltip('Definição de tarefas'), findsNothing);
  });

  testWidgets('sair do modo criança exige o PIN', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
      prefs: const {'activeProfile': 'none'},
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia'], withPin: false);
    await seedRealPin(app.db, 'uid-ana', '4321');
    await pumpSettled(tester, app.widget);

    await tester.tap(find.text('Bia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sair do modo criança'));
    await tester.pumpAndSettle();

    expect(find.text('Sair do modo criança'), findsWidgets); // título do prompt

    // PIN errado
    await tester.enterText(find.byType(TextField), '0000');
    await tester.pumpAndSettle();
    expect(find.text('PIN incorreto.'), findsOneWidget);

    // PIN certo -> volta ao seletor
    await tester.enterText(find.byType(TextField), '4321');
    await tester.pumpAndSettle();
    expect(find.text('Quem é você?'), findsOneWidget);
  });
}
