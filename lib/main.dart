import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/children_tasks_app.dart';
import 'src/app/firebase/firebase_bootstrap.dart';
import 'src/app/firebase/firebase_providers.dart';
import 'src/features/notifications/application/notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebase = await initFirebase();

  if (firebase == FirebaseInitStatus.ready) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseInitStatusProvider.overrideWithValue(firebase),
      ],
      child: const ChildrenTasksApp(),
    ),
  );
}
