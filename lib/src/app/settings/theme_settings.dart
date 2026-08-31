import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instância de [SharedPreferences], resolvida em `main()` e injetada por
/// override no `ProviderScope`. Sobrescrita nos testes (ver `buildTestApp`).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider deve ser sobrescrito em main()/testes');
});

/// Modo de tema escolhido pelo usuário. Preferência **local do dispositivo**
/// (não sincroniza entre aparelhos): vale para os dois papéis e desde a tela
/// de login. Default: acompanha o sistema.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _prefsKey = 'app.themeMode';

  @override
  ThemeMode build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_prefsKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_prefsKey, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Rótulo pt-BR de cada [ThemeMode], para a UI de ajustes.
extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
        ThemeMode.system => 'Padrão do sistema',
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Escuro',
      };

  IconData get icon => switch (this) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };
}
