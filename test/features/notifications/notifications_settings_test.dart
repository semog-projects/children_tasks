import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('altera uma preferência de notificação', (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana', childNames: ['Bia']);
    await pumpSettled(tester, app.widget);

    await openHomeMenu(tester, 'Família');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notificações'));
    await tester.pumpAndSettle();

    // desliga "Recompensa resgatada"
    await tester.tap(find.widgetWithText(SwitchListTile, 'Recompensa resgatada'));
    await tester.pumpAndSettle();

    final user = await app.db.collection('users').doc('uid-ana').get();
    final notif = user.data()!['notif'] as Map<String, dynamic>;
    expect(notif['redemption'], false);
    expect(notif['pendingApproval'], true);
  });
}
