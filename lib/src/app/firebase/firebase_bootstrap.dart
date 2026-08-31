import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../env.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

/// Resultado da inicialização do Firebase.
enum FirebaseInitStatus {
  /// Inicializado e pronto.
  ready,

  /// `flutterfire configure` ainda não rodou para este flavor — o app segue
  /// funcionando sem backend (estado de bootstrap).
  notConfigured,
}

FirebaseOptions get _optionsForFlavor => switch (AppFlavor.current) {
      AppFlavor.dev => dev.DefaultFirebaseOptions.currentPlatform,
      AppFlavor.prod => prod.DefaultFirebaseOptions.currentPlatform,
    };

/// Inicializa o Firebase para o [AppFlavor] atual e, em dev, aponta os SDKs
/// para o Emulator Suite. Idempotente.
Future<FirebaseInitStatus> initFirebase() async {
  final FirebaseOptions options;
  try {
    options = _optionsForFlavor;
  } on UnsupportedError catch (e) {
    debugPrint('Firebase não configurado (${AppFlavor.current.name}): $e');
    return FirebaseInitStatus.notConfigured;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }

  _enableOfflinePersistence();

  if (useFirebaseEmulator) {
    _useEmulators();
  }

  return FirebaseInitStatus.ready;
}

/// Cache offline do Firestore. Mobile já vem ligado; no web precisa ser
/// explícito. Deve rodar antes de qualquer query.
void _enableOfflinePersistence() {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Persistência offline não disponível nesta plataforma: $e');
  }
}

bool _emulatorsConnected = false;

void _useEmulators() {
  if (_emulatorsConnected) return;
  _emulatorsConnected = true;

  const host = firebaseEmulatorHost;
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFunctions.instanceFor(region: 'southamerica-east1')
      .useFunctionsEmulator(host, 5001);
  // ignore: discarded_futures — a API do plugin é assíncrona mas fire-and-forget aqui.
  FirebaseAuth.instance.useAuthEmulator(host, 9099);
  debugPrint(
    'Firebase: usando emuladores em $host (firestore:8080, auth:9099, functions:5001)',
  );
}
