/// Ambiente de execução do app. Selecionado em tempo de compilação via
/// `--dart-define=FLAVOR=prod` (padrão: `dev`).
enum AppFlavor {
  dev,
  prod;

  static const String _raw = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static const AppFlavor current = _raw == 'prod' ? AppFlavor.prod : AppFlavor.dev;

  bool get isDev => this == AppFlavor.dev;
  bool get isProd => this == AppFlavor.prod;
}

/// Liga os emuladores do Firebase. Padrão: ligado em `dev`, desligado em `prod`.
/// Force com `--dart-define=USE_FIREBASE_EMULATOR=true|false`.
const bool useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: !bool.fromEnvironment('dart.vm.product'),
);

/// Host dos emuladores. Em Android, `localhost` do emulador é `10.0.2.2`.
const String firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);
