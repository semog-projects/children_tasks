import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_prefs.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(firestoreRefsProvider));
});

/// Preferências de notificação do responsável logado.
final notificationPrefsProvider = StreamProvider<NotificationPrefs>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const NotificationPrefs());
  return ref.watch(notificationsRepositoryProvider).watchPrefs(uid);
});

class NotificationPrefsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save(NotificationPrefs prefs) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).savePrefs(uid, prefs),
    );
  }
}

final notificationPrefsControllerProvider =
    AsyncNotifierProvider<NotificationPrefsController, void>(
        NotificationPrefsController.new);

String currentPlatformName() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name;
}
