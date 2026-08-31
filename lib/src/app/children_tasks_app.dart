import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/presentation/home_screen.dart';
import 'theme.dart';

/// Locale único do app. O projeto é PT-BR apenas (ver README).
const Locale kAppLocale = Locale('pt', 'BR');

/// Raiz da árvore de widgets: configura tema, localização e rota inicial.
class ChildrenTasksApp extends ConsumerWidget {
  const ChildrenTasksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Tarefas das Crianças',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: kAppLocale,
      supportedLocales: const [kAppLocale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeScreen(),
    );
  }
}
