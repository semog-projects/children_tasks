import 'package:childrentasks/src/app/children_tasks_app.dart';
import 'package:childrentasks/src/app/firebase/firebase_bootstrap.dart';
import 'package:childrentasks/src/app/firebase/firebase_providers.dart';
import 'package:childrentasks/src/features/auth/application/auth_providers.dart';
import 'package:childrentasks/src/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

Widget _app(FakeAuthRepository auth) => ProviderScope(
      overrides: [
        firebaseInitStatusProvider.overrideWithValue(FirebaseInitStatus.ready),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      child: const ChildrenTasksApp(),
    );

void main() {
  testWidgets('login pelo botão leva à home', (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    expect(find.text('Projeto em bootstrap'), findsOneWidget);
  });

  testWidgets('logout volta para a tela de login', (tester) async {
    final auth = FakeAuthRepository(initialUser: FakeAuthRepository.user());
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar com Google'), findsOneWidget);
  });

  testWidgets('erro no login mostra snackbar e não navega', (tester) async {
    final auth = FakeAuthRepository(
      onSignIn: (_) async => throw const AuthException('Falha no login com o Google.'),
    );
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar com Google'));
    await tester.pump(); // dispara o listener
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Falha no login com o Google.'), findsOneWidget);
    expect(find.text('Projeto em bootstrap'), findsNothing);
  });

  testWidgets('cancelamento não é tratado como erro', (tester) async {
    final auth = FakeAuthRepository(
      onSignIn: (_) async => throw const AuthCancelledException(),
    );
    await tester.pumpWidget(_app(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar com Google'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Entrar com Google'), findsOneWidget);
  });
}
