import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../features/family/application/family_providers.dart';

bool _hasNetwork(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Estado de rede. Emite o valor atual na inscrição e a cada mudança.
/// Sobrescrito nos testes.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _hasNetwork(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_hasNetwork);
});

/// `true` (otimista) enquanto o estado não resolveu.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).asData?.value ?? true;
});

/// Há escritas locais ainda não confirmadas pelo servidor?
final pendingWritesProvider = StreamProvider<bool>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(false);
  return ref
      .watch(firestoreRefsProvider)
      .family(family.id)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.metadata.hasPendingWrites);
});

/// Texto do banner de sincronização, ou `null` quando está tudo em dia.
final syncBannerProvider = Provider<String?>((ref) {
  if (!ref.watch(isOnlineProvider)) {
    return 'Sem conexão — as alterações serão sincronizadas quando a internet voltar.';
  }
  final pending = ref.watch(pendingWritesProvider).asData?.value ?? false;
  return pending ? 'Sincronizando alterações…' : null;
});
