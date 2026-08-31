import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase/firebase_providers.dart';
import '../data/invites_repository.dart';

final invitesRepositoryProvider = Provider<InvitesRepository>((ref) {
  return FirebaseInvitesRepository(ref.watch(functionsProvider));
});

/// Aceita um convite pelo código (usado na tela de boas-vindas). `true` no
/// sucesso; o `RoleGate` reage sozinho à mudança de papel.
class AcceptInviteController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> accept(String code) async {
    state = const AsyncLoading();
    try {
      await ref.read(invitesRepositoryProvider).accept(code);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}

final acceptInviteControllerProvider =
    AsyncNotifierProvider<AcceptInviteController, void>(
  AcceptInviteController.new,
);
