import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_gate.dart';
import 'settings/theme_settings.dart';
import 'theme.dart';

/// Locale único do app. O projeto é PT-BR apenas (ver README).
const Locale kAppLocale = Locale('pt', 'BR');

/// Chaves globais para mostrar snackbars / navegar a partir de notificações
/// FCM (fora da árvore de um `BuildContext`).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

/// Raiz da árvore de widgets: configura tema, localização e rota inicial.
class ChildrenTasksApp extends ConsumerWidget {
  const ChildrenTasksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Tarefas das Crianças',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: kAppLocale,
      supportedLocales: const [kAppLocale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
