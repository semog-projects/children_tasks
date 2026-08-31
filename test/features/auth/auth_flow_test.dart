import 'package:childrentasks/src/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('login pelo botão leva à tela de boas-vindas', (tester) async {
    final app = await buildTestApp(auth: FakeAuthRepository());
    await pumpSettled(tester, app.widget);

    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    expect(find.text('Criar uma família'), findsOneWidget);
  });

  testWidgets('logout volta para a tela de login', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana');
    await pumpSettled(tester, app.widget);

    await tester.tap(find.byTooltip('Sair da conta'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('erro no login mostra snackbar e não navega', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(
        onSignIn: (_) async => throw const AuthException('Falha no login com o Google.'),
      ),
    );
    await pumpSettled(tester, app.widget);

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Falha no login com o Google.'), findsOneWidget);
    expect(find.text('Criar uma família'), findsNothing);
  });

  testWidgets('cancelamento não é tratado como erro', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(
        onSignIn: (_) async => throw const AuthCancelledException(),
      ),
    );
    await pumpSettled(tester, app.widget);

    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });
}
