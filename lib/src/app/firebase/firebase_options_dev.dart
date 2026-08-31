// PLACEHOLDER — este arquivo é SOBRESCRITO pelo FlutterFire CLI.
//
// Rode (uma vez, com o projeto Firebase de desenvolvimento):
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure \
//     --project=<seu-projeto-dev> \
//     --out=lib/src/app/firebase/firebase_options_dev.dart \
//     --platforms=android,ios,web,windows,macos
//
// Enquanto não rodar, `AppFlavor.dev` não inicializa o Firebase (o app
// segue rodando sem backend). Ver README > "Configuração do Firebase".
//
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'firebase_options_dev.dart ainda é o placeholder. '
      'Rode `flutterfire configure` para o projeto Firebase de dev '
      '(ver instruções no topo deste arquivo).',
    );
  }
}
