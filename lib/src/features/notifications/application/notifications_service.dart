import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/children_tasks_app.dart';
import '../../auth/application/auth_providers.dart';
import '../../tasks/presentation/approvals_screen.dart';
import 'notifications_providers.dart';

/// VAPID key para push no web. `--dart-define=FCM_VAPID_KEY=...`. Vazio = web
/// sem push (mobile funciona sem isso).
const _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Handler de mensagem em background (mobile). No web é o service worker.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nada a fazer: o SO já exibe a notificação. Ponto de extensão futuro.
}

/// Registra o dispositivo para notificações e trata as mensagens recebidas.
/// Chamado uma vez quando há responsável logado (FamilyGate).
class NotificationsService {
  NotificationsService(this._ref);

  final Ref _ref;
  bool _started = false;
  final _subs = <StreamSubscription<dynamic>>[];

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notificações negadas pelo usuário');
        return;
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _saveToken(await messaging.getToken(
        vapidKey: kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null,
      ));

      _subs.add(messaging.onTokenRefresh.listen(_saveToken));
      _subs.add(FirebaseMessaging.onMessage.listen(_onForeground));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_onOpened));

      final initial = await messaging.getInitialMessage();
      if (initial != null) _onOpened(initial);
    } catch (error) {
      debugPrint('Notificações indisponíveis nesta plataforma: $error');
    }
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  Future<void> _saveToken(String? token) async {
    final uid = _ref.read(currentUserProvider)?.uid;
    if (uid == null || token == null || token.isEmpty) return;
    await _ref
        .read(notificationsRepositoryProvider)
        .saveToken(uid, token, platform: currentPlatformName());
  }

  void _onForeground(RemoteMessage message) {
    final n = message.notification;
    final text = n?.body ?? n?.title;
    if (text == null) return;
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _onOpened(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'pendingApproval') {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const ApprovalsScreen()),
      );
    }
  }
}

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  final service = NotificationsService(ref);
  ref.onDispose(service.dispose);
  return service;
});
