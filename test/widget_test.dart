import 'package:childrentasks/src/app/firebase/firebase_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/test_harness.dart';

void main() {
  testWidgets('deslogado: mostra a tela de login', (tester) async {
    final app = await buildTestApp();
    await pumpSettled(tester, app.widget);

    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('Firebase indisponível: bloqueia antes do login', (tester) async {
    final app = await buildTestApp(firebase: FirebaseInitStatus.notConfigured);
    await pumpSettled(tester, app.widget);

    expect(find.text('Backend indisponível'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsNothing);
  });

  testWidgets('logado sem família: abre o onboarding', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await pumpSettled(tester, app.widget);

    expect(find.text('Criar família'), findsOneWidget);
  });

  testWidgets('logado com família: abre a home com as crianças', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', name: 'Família Silva', childNames: ['Bia']);
    await pumpSettled(tester, app.widget);

    expect(find.text('Família Silva'), findsOneWidget);
    expect(find.text('Bia'), findsOneWidget);
  });

  testWidgets('usa locale pt-BR', (tester) async {
    final app = await buildTestApp();
    await pumpSettled(tester, app.widget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.locale, const Locale('pt', 'BR'));
  });
}
