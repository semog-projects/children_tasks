import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/firestore_refs.dart';
import '../domain/notification_prefs.dart';

/// Tokens FCM e preferências de notificação do responsável logado.
class NotificationsRepository {
  NotificationsRepository(this._refs);

  final FirestoreRefs _refs;

  Stream<NotificationPrefs> watchPrefs(String uid) {
    return _refs
        .user(uid)
        .snapshots()
        .map((doc) => NotificationPrefs.fromMap(doc.data()?['notif'] as Map<String, dynamic>?));
  }

  Future<void> savePrefs(String uid, NotificationPrefs prefs) {
    return _refs.user(uid).set({'notif': prefs.toMap()}, SetOptions(merge: true));
  }

  /// Registra/atualiza um token FCM deste dispositivo.
  Future<void> saveToken(String uid, String token, {required String platform}) {
    return _refs.fcmTokens(uid).doc(token).set({
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeToken(String uid, String token) {
    return _refs.fcmTokens(uid).doc(token).delete();
  }
}
