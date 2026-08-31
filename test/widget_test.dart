import 'package:childrentasks/src/app/children_tasks_app.dart';
import 'package:childrentasks/src/app/firebase/firebase_bootstrap.dart';
import 'package:childrentasks/src/app/firebase/firebase_providers.dart';
import 'package:childrentasks/src/features/auth/application/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

Widget _app({
  FirebaseInitStatus firebase = FirebaseInitStatus.ready,
  FakeAuthRepository? auth,
}) {
  return ProviderScope(
    overrides: [
      firebaseInitStatusProvider.overrideWithValue(firebase),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
    ],
    child: const ChildrenTasksApp(),
  );
}

void main() {
  testWidgets('deslogado: mostra a tela de login', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('Projeto em bootstrap'), findsNothing);
  });

  testWidgets('logado: mostra a home', (tester) async {
    await tester.pumpWidget(
      _app(auth: FakeAuthRepository(initialUser: FakeAuthRepository.user())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Projeto em bootstrap'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('usa locale pt-BR', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('pt', 'BR'));
  });

  testWidgets('Firebase indisponível: bloqueia antes do login', (tester) async {
    await tester.pumpWidget(_app(firebase: FirebaseInitStatus.notConfigured));
    await tester.pumpAndSettle();

    expect(find.text('Backend indisponível'), findsOneWidget);
    expect(find.text('Entrar com Google'), findsNothing);
  });
}
