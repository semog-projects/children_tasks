import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_harness.dart';

void main() {
  testWidgets('sem preferência salva, o app segue o sistema', (tester) async {
    final app = await buildTestApp();
    await pumpSettled(tester, app.widget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.system);
  });

  testWidgets('preferência salva é aplicada no boot', (tester) async {
    final app = await buildTestApp(prefs: {'app.themeMode': 'dark'});
    await pumpSettled(tester, app.widget);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
  });

  testWidgets('trocar o tema na tela de Aparência aplica e persiste',
      (tester) async {
    final app = await buildTestApp(
      auth: FakeAuthRepository(initialUser: FakeAuthRepository.user()),
    );
    await seedFamily(app.db, uid: 'uid-ana');
    await pumpSettled(tester, app.widget);

    await openHomeMenu(tester, 'Família');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aparência'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app.themeMode'), 'dark');
  });
}
