import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/family.dart';
import '../../family/application/family_providers.dart';

/// Liga/desliga funcionalidades do app para a família (issue #75). Desligar
/// esconde os pontos de entrada e a Cloud Function recusa a ação.
class FeaturesScreen extends ConsumerWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(currentFamilyProvider).asData?.value;
    final controller = ref.read(familyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Funcionalidades')),
      body: family == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Tarefas e pontos ficam sempre ligados. O que você desligar '
                    'aqui some do app pra você e pra criança.',
                  ),
                ),
                for (final feature in AppFeature.values)
                  SwitchListTile(
                    title: Text(feature.label),
                    subtitle: Text(feature.description),
                    value: family.isEnabled(feature),
                    onChanged: (v) => controller.setFeatureEnabled(feature, v),
                  ),
              ],
            ),
    );
  }
}
