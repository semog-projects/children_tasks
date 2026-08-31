import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app/children_tasks_app.dart';
import 'src/app/firebase/firebase_bootstrap.dart';
import 'src/app/firebase/firebase_providers.dart';
import 'src/features/profiles/application/profile_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebase = await initFirebase();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        firebaseInitStatusProvider.overrideWithValue(firebase),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ChildrenTasksApp(),
    ),
  );
}
