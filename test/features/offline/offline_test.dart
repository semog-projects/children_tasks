import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('offline: mostra a faixa de aviso na home', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
      online: false,
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    await pumpSettled(tester, app.widget);

    expect(find.textContaining('Sem conexão'), findsOneWidget);
  });

  testWidgets('online: sem faixa', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    await pumpSettled(tester, app.widget);

    expect(find.textContaining('Sem conexão'), findsNothing);
    expect(find.textContaining('Sincronizando'), findsNothing);
  });

  testWidgets('offline: resgate fica desabilitado no catálogo', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
      online: false,
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    await app.db.collection('families').doc(familyId).collection('rewards').add({
      'title': 'Sorvete',
      'cost': 10,
      'active': true,
      'stock': null,
    });
    // saldo suficiente
    await app.db.collection('families').doc(familyId).collection('ledger').add({
      'memberId':
          (await app.db.collection('families').doc(familyId).collection('members').get())
              .docs
              .single
              .id,
      'type': 'earn',
      'points': 100,
      'sourceType': 'taskInstance',
      'createdByUid': 'system',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await pumpSettled(tester, app.widget);

    await tester.tap(find.byTooltip('Recompensas de Bia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('resgate precisa de internet'), findsOneWidget);
    final btn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Resgatar'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('marcar tarefa feita funciona offline (só muda status local)',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
      online: false,
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
    final ref = await app.db
        .collection('families')
        .doc(familyId)
        .collection('taskInstances')
        .add({
      'taskId': 't1',
      'memberId': child.id,
      'date': Timestamp.fromDate(DateTime.utc(now.year, now.month, now.day)),
      'status': 'pending',
      'titleSnapshot': 'Cama',
      'pointsSnapshot': 10,
      'requiresApproval': true,
    });

    await pumpSettled(tester, app.widget);
    await tester.tap(find.text('Tarefas de hoje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feita'));
    await tester.pumpAndSettle();

    final doc = await app.db
        .collection('families')
        .doc(familyId)
        .collection('taskInstances')
        .doc(ref.id)
        .get();
    expect(doc.data()!['status'], 'awaitingApproval');

    // saldo continua zero — nenhum ponto creditado localmente
    final ledger =
        await app.db.collection('families').doc(familyId).collection('ledger').get();
    expect(ledger.docs, isEmpty);
  });
}
