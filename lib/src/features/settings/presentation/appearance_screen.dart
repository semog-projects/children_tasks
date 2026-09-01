import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/settings/theme_settings.dart';

/// Ajustes de aparência. Por ora, só o modo de tema (claro/escuro/sistema).
/// A preferência é local do aparelho — vale para responsável e criança.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aparência')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: mode,
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).set(value);
              }
            },
            child: Column(
              children: [
                for (final option in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    value: option,
                    secondary: Icon(option.icon),
                    title: Text(option.label),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Vale só neste aparelho.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
