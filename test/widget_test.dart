import 'package:childrentasks/src/app/children_tasks_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app inicia na tela de bootstrap', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ChildrenTasksApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Projeto em bootstrap'), findsOneWidget);
    // Um dos itens do roadmap espelhado do backlog.
    expect(find.textContaining('Google Sign-In'), findsOneWidget);
  });

  testWidgets('usa locale pt-BR', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ChildrenTasksApp()),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('pt', 'BR'));
  });
}
