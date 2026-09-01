import 'package:childrentasks/src/common/empty_hint.dart';
import 'package:childrentasks/src/common/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StatCard mostra valor, rótulo e barra de progresso opcional',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatCard(
          icon: Icons.stars_rounded,
          value: '30 pontos',
          label: 'Saldo disponível',
          progress: 0.5,
        ),
      ),
    ));

    expect(find.text('30 pontos'), findsOneWidget);
    expect(find.text('Saldo disponível'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('EmptyHint mostra ícone, mensagem e ação opcional',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyHint(
          icon: Icons.history_rounded,
          message: 'Nenhum resgate ainda.',
          action: FilledButton(onPressed: () {}, child: const Text('Adicionar')),
        ),
      ),
    ));

    expect(find.text('Nenhum resgate ainda.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Adicionar'), findsOneWidget);
  });
}
