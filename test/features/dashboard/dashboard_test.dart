import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

Future<void> _ledger(
  FakeFirebaseFirestore db,
  String familyId, {
  required String memberId,
  required int points,
  required String type,
  required DateTime at,
  String? memberUid,
}) async {
  await db.collection('families').doc(familyId).collection('ledger').add({
    'memberId': memberId,
    'memberUid': ?memberUid,
    'type': type,
    'points': points,
    'sourceType': type == 'redeem' ? 'reward' : 'taskInstance',
    'createdByUid': 'system',
    'createdAt': Timestamp.fromDate(at),
  });
}

void main() {
  testWidgets('painel mostra resumo por criança com pontos da semana', (tester) async {
    final app = await buildTestApp(
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
    await _ledger(app.db, familyId,
        memberId: child.id, points: 10, type: 'earn', at: now.subtract(const Duration(days: 1)));
    await _ledger(app.db, familyId,
        memberId: child.id, points: 5, type: 'earn', at: now.subtract(const Duration(days: 2)));
    await _ledger(app.db, familyId,
        memberId: child.id, points: -8, type: 'redeem', at: now.subtract(const Duration(days: 1)));

    await pumpSettled(tester, app.widget);
    await openHomeMenu(tester, 'Painel');
    await tester.pumpAndSettle();

    expect(find.text('Painel'), findsOneWidget);
    // saldo = 10 + 5 - 8 = 7 ; semana (créditos) = 15
    expect(find.textContaining('+15 pts na semana'), findsOneWidget);
    expect(find.text('7 pts'), findsOneWidget);
  });

  testWidgets('histórico filtra por período', (tester) async {
    final app = await buildTestApp(
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
    await _ledger(app.db, familyId,
        memberId: child.id, points: 10, type: 'earn', at: now.subtract(const Duration(days: 3)));
    await _ledger(app.db, familyId,
        memberId: child.id, points: 20, type: 'earn', at: now.subtract(const Duration(days: 50)));

    await pumpSettled(tester, app.widget);
    await openHomeMenu(tester, 'Painel');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Histórico'));
    await tester.pumpAndSettle();

    // período default = 30 dias -> só a entrada de 3 dias atrás
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('+20'), findsNothing);

    // muda para 90 dias -> aparece a de 50 dias
    await tester.tap(find.text('Últimos 30 dias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Últimos 90 dias').last);
    await tester.pumpAndSettle();
    expect(find.text('+20'), findsOneWidget);
  });

  testWidgets('criança logada vê a próxima recompensa', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(
        initialUser: FakeAuthRepository.user(
          name: 'Bia',
          email: 'bia@example.com',
          uid: 'uid-bia',
        ),
      ),
    );
    final familyId = await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    final child = (await app.db
            .collection('families')
            .doc(familyId)
            .collection('members')
            .get())
        .docs
        .single;
    await seedChildLogin(app.db, familyId, memberId: child.id, uid: 'uid-bia');
    await app.db.collection('families').doc(familyId).collection('rewards').add({
      'title': 'Cinema',
      'cost': 100,
      'active': true,
      'stock': null,
    });
    await _ledger(app.db, familyId,
        memberId: child.id,
        memberUid: 'uid-bia',
        points: 30,
        type: 'earn',
        at: DateTime.now());

    await pumpSettled(tester, app.widget);

    expect(find.text('Olá, Bia!'), findsOneWidget);
    expect(find.text('Cinema'), findsOneWidget);
    expect(find.text('Faltam 70 pontos'), findsOneWidget);
  });
}
