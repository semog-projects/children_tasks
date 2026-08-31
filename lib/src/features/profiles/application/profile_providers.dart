import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/data_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/pin_repository.dart';
import '../domain/active_profile.dart';

/// `SharedPreferences` resolvido em `main()` e injetado por override.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider deve ser sobrescrito em main()/testes');
});

final pinRepositoryProvider = Provider<PinRepository>((ref) {
  return PinRepository(ref.watch(firestoreRefsProvider));
});

/// `true` se o responsável logado já definiu um PIN.
final hasPinProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return false;
  return ref.watch(pinRepositoryProvider).hasPin(uid);
});

const _activeProfileKey = 'activeProfile';

/// Perfil ativo, persistido localmente (volta ao mesmo perfil ao reabrir).
class ActiveProfileNotifier extends Notifier<ActiveProfile> {
  @override
  ActiveProfile build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_activeProfileKey);
    return ActiveProfile.decode(raw);
  }

  Future<void> _persist(ActiveProfile profile) async {
    state = profile;
    await ref.read(sharedPreferencesProvider).setString(_activeProfileKey, profile.encode());
  }

  Future<void> selectGuardian() => _persist(const ActiveProfile.guardian());
  Future<void> selectChild(String memberId) => _persist(ActiveProfile.child(memberId));
  Future<void> backToSelector() => _persist(const ActiveProfile.none());
}

final activeProfileProvider =
    NotifierProvider<ActiveProfileNotifier, ActiveProfile>(ActiveProfileNotifier.new);

/// Verificação de PIN com limite de tentativas (bloqueia por um tempo).
class PinCheckState {
  const PinCheckState({this.failedAttempts = 0, this.lockedUntil});

  final int failedAttempts;
  final DateTime? lockedUntil;

  bool get isLocked =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  Duration get remainingLock =>
      isLocked ? lockedUntil!.difference(DateTime.now()) : Duration.zero;
}

class PinCheckNotifier extends Notifier<PinCheckState> {
  static const _maxAttempts = 5;
  static const _lockDuration = Duration(seconds: 30);

  @override
  PinCheckState build() => const PinCheckState();

  /// Retorna `true` se o PIN confere. Em erro, conta a tentativa e pode travar.
  Future<bool> verify(String pin) async {
    if (state.isLocked) return false;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return false;

    final ok = await ref.read(pinRepositoryProvider).verifyPin(uid, pin);
    if (ok) {
      state = const PinCheckState();
      return true;
    }

    final attempts = state.failedAttempts + 1;
    state = PinCheckState(
      failedAttempts: attempts,
      lockedUntil: attempts >= _maxAttempts ? DateTime.now().add(_lockDuration) : null,
    );
    return false;
  }
}

final pinCheckProvider =
    NotifierProvider<PinCheckNotifier, PinCheckState>(PinCheckNotifier.new);
