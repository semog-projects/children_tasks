// PLACEHOLDER — este arquivo é SOBRESCRITO pelo FlutterFire CLI.
//
// Rode (uma vez, com o projeto Firebase de produção):
//
//   flutterfire configure \
//     --project=<seu-projeto-prod> \
//     --out=lib/src/app/firebase/firebase_options_prod.dart \
//     --platforms=android,ios,web,windows,macos
//
// Ver README > "Configuração do Firebase".
//
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'firebase_options_prod.dart ainda é o placeholder. '
      'Rode `flutterfire configure` para o projeto Firebase de prod '
      '(ver instruções no topo deste arquivo).',
    );
  }
}
