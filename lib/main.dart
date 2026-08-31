import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/children_tasks_app.dart';
import 'src/app/firebase/firebase_bootstrap.dart';
import 'src/app/firebase/firebase_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebase = await initFirebase();

  runApp(
    ProviderScope(
      overrides: [
        firebaseInitStatusProvider.overrideWithValue(firebase),
      ],
      child: const ChildrenTasksApp(),
    ),
  );
}
