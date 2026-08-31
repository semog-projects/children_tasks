import 'package:childrentasks/src/data/models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

Future<void> _openTasks(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Tarefas'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('cria uma tarefa pelo formulário', (tester) async {
    final app = buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana');
    await pumpSettled(tester, app.widget);
    await _openTasks(tester);

    await tester.tap(find.text('Tarefa'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Arrumar a cama');
    await tester.enterText(find.widgetWithText(TextFormField, 'Pontos'), '15');
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Arrumar a cama'), findsOneWidget);

    final tasks =
        await app.db.collection('families').doc(familyId).collection('tasks').get();
    expect(tasks.docs.single.data()['points'], 15);
    expect(tasks.docs.single.data()['active'], true);
  });

  testWidgets('valida título e pontos', (tester) async {
    final app = buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana');
    await pumpSettled(tester, app.widget);
    await _openTasks(tester);
    await tester.tap(find.text('Tarefa'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Pontos'), '0');
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe um título'), findsOneWidget);
    expect(find.text('Informe um número maior que zero'), findsOneWidget);
  });

  testWidgets('arquivar tira da lista ativa e reativar traz de volta', (tester) async {
    final app = buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana');
    await app.db.collection('families').doc(familyId).collection('tasks').add({
      'title': 'Ler 15 min',
      'description': null,
      'points': 5,
      'category': 'study',
      'assigneeMemberId': null,
      'recurrence': {'type': 'daily', 'daysOfWeek': <int>[], 'startDate': DateTime(2026, 8, 1), 'endDate': null},
      'requiresApproval': true,
      'active': true,
    });
    await pumpSettled(tester, app.widget);
    await _openTasks(tester);

    expect(find.text('Ler 15 min'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();
    expect(find.text('Ler 15 min'), findsNothing);

    // alterna para a visão de arquivadas
    await tester.tap(find.byTooltip('Ver arquivadas'));
    await tester.pumpAndSettle();
    expect(find.text('Ler 15 min'), findsOneWidget);
  });

  testWidgets('home mostra o progresso das tarefas de hoje por criança', (tester) async {
    final app = buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = (await app.db
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get())
        .docs
        .single;
    final now = DateTime.now();
    final today = Timestamp.fromDate(DateTime.utc(now.year, now.month, now.day));
    final instances = app.db.collection('families').doc(familyId).collection('taskInstances');
    await instances.add({
      'taskId': 't1', 'memberId': child.id, 'date': today, 'status': 'pending',
      'titleSnapshot': 'Cama', 'pointsSnapshot': 10, 'requiresApproval': true,
    });
    await instances.add({
      'taskId': 't2', 'memberId': child.id, 'date': today, 'status': 'approved',
      'titleSnapshot': 'Ler', 'pointsSnapshot': 5, 'requiresApproval': true,
    });
    await pumpSettled(tester, app.widget);

    expect(find.text('1 de 2 tarefas hoje'), findsOneWidget);
  });

  test('Recurrence.summary resume a repetição', () {
    final weekly = Recurrence(
      type: RecurrenceType.weekly,
      daysOfWeek: const [5, 1, 3],
      startDate: DateTime(2026),
    );
    expect(weekly.summary, 'Seg, Qua, Sex');
    expect(
      Recurrence(type: RecurrenceType.daily, startDate: DateTime(2026)).summary,
      'Todo dia',
    );
    expect(
      Recurrence(type: RecurrenceType.once, startDate: DateTime(2026)).summary,
      'Uma vez',
    );
  });
}
