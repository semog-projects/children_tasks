import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notifications_providers.dart';
import '../domain/notification_prefs.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider).asData?.value ?? const NotificationPrefs();
    final controller = ref.read(notificationPrefsControllerProvider.notifier);

    void save(NotificationPrefs next) => controller.save(next);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tarefa aguardando aprovação'),
            value: prefs.pendingApproval,
            onChanged: (v) => save(prefs.copyWith(pendingApproval: v)),
          ),
          SwitchListTile(
            title: const Text('Resultado da aprovação'),
            subtitle: const Text('Quando uma tarefa é aprovada ou rejeitada'),
            value: prefs.approvalResult,
            onChanged: (v) => save(prefs.copyWith(approvalResult: v)),
          ),
          SwitchListTile(
            title: const Text('Recompensa resgatada'),
            value: prefs.redemption,
            onChanged: (v) => save(prefs.copyWith(redemption: v)),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Lembrete diário'),
            subtitle: Text('Todo dia às ${prefs.reminderHour.toString().padLeft(2, '0')}:00'),
            value: prefs.dailyReminder,
            onChanged: (v) => save(prefs.copyWith(dailyReminder: v)),
          ),
          if (prefs.dailyReminder)
            ListTile(
              title: const Text('Horário do lembrete'),
              trailing: Text('${prefs.reminderHour.toString().padLeft(2, '0')}:00'),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: prefs.reminderHour, minute: 0),
                );
                if (picked != null) save(prefs.copyWith(reminderHour: picked.hour));
              },
            ),
        ],
      ),
    );
  }
}
