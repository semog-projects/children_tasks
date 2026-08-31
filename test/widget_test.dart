import 'package:childrentasks/src/app/children_tasks_app.dart';
import 'package:childrentasks/src/app/firebase/firebase_bootstrap.dart';
import 'package:childrentasks/src/app/firebase/firebase_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({FirebaseInitStatus firebase = FirebaseInitStatus.notConfigured}) {
  return ProviderScope(
    overrides: [
      firebaseInitStatusProvider.overrideWithValue(firebase),
    ],
    child: const ChildrenTasksApp(),
  );
}

void main() {
  testWidgets('app inicia na tela de bootstrap', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Projeto em bootstrap'), findsOneWidget);
    expect(find.textContaining('Google Sign-In'), findsOneWidget);
  });

  testWidgets('usa locale pt-BR', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('pt', 'BR'));
  });

  testWidgets('mostra status do Firebase', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Firebase indisponível'), findsOneWidget);

    await tester.pumpWidget(_app(firebase: FirebaseInitStatus.ready));
    await tester.pumpAndSettle();
    expect(find.text('Firebase conectado'), findsOneWidget);
  });
}
