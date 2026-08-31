import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/application/notifications_providers.dart';
import '../../notifications/domain/notification_prefs.dart';

/// Preferências de notificação da criança (versão enxuta — issue #35).
class ChildNotificationsScreen extends ConsumerWidget {
  const ChildNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider).asData?.value ??
        const NotificationPrefs();
    final controller = ref.read(notificationPrefsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tarefa aprovada'),
            subtitle: const Text('Quando o responsável aprova e os pontos entram'),
            value: prefs.taskApproved,
            onChanged: (v) => controller.save(prefs.copyWith(taskApproved: v)),
          ),
          SwitchListTile(
            title: const Text('Tarefa para refazer'),
            subtitle: const Text('Quando o responsável pede para refazer'),
            value: prefs.taskRejected,
            onChanged: (v) => controller.save(prefs.copyWith(taskRejected: v)),
          ),
          SwitchListTile(
            title: const Text('Recompensa entregue'),
            value: prefs.rewardDelivered,
            onChanged: (v) => controller.save(prefs.copyWith(rewardDelivered: v)),
          ),
        ],
      ),
    );
  }
}
