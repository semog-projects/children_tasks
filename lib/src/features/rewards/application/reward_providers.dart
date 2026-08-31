import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase/firebase_providers.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/redemption.dart';
import '../../../data/models/reward.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';

final activeRewardsProvider = StreamProvider<List<Reward>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(rewardRepositoryProvider).watchActive(family.id);
});

final allRewardsProvider = StreamProvider<List<Reward>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(rewardRepositoryProvider).watchAll(family.id);
});

final redemptionsProvider = StreamProvider<List<Redemption>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(redemptionRepositoryProvider).watchAll(family.id);
});

final pendingDeliveryProvider = StreamProvider<List<Redemption>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(redemptionRepositoryProvider).watchPendingDelivery(family.id);
});

final childRedemptionsProvider =
    StreamProvider.family<List<Redemption>, String>((ref, memberId) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref
      .watch(redemptionRepositoryProvider)
      .watchForMember(family.id, memberId);
});

/// CRUD de recompensas (responsável).
class RewardController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _familyId => ref.read(currentFamilyIdProvider);

  Future<void> save(Reward reward) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(rewardRepositoryProvider);
      if (reward.id.isEmpty) {
        await repo.create(_familyId, reward);
      } else {
        await repo.update(_familyId, reward);
      }
    });
  }

  Future<void> setActive(Reward reward, {required bool active}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(rewardRepositoryProvider).update(
            _familyId,
            reward.copyWith(active: active),
          ),
    );
  }
}

final rewardControllerProvider =
    AsyncNotifierProvider<RewardController, void>(RewardController.new);

/// Erro de negócio no resgate (saldo, estoque…), com mensagem pt-BR.
class RedeemException implements Exception {
  const RedeemException(this.message);
  final String message;
}

/// Resgate (via Cloud Function) e marcação de entrega.
class RedemptionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _familyId => ref.read(currentFamilyIdProvider);

  Future<void> redeem({required String rewardId, required String memberId}) async {
    state = const AsyncLoading();
    try {
      await ref.read(functionsProvider).httpsCallable('redeemReward').call<dynamic>({
        'familyId': _familyId,
        'rewardId': rewardId,
        'memberId': memberId,
      });
      state = const AsyncData(null);
    } on FirebaseFunctionsException catch (e, st) {
      state = AsyncError(RedeemException(e.message ?? 'Não foi possível resgatar.'), st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> markDelivered(String redemptionId) async {
    final uid = ref.read(currentUserProvider)!.uid;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(redemptionRepositoryProvider)
          .markDelivered(_familyId, redemptionId, uid),
    );
  }
}

final redemptionControllerProvider =
    AsyncNotifierProvider<RedemptionController, void>(RedemptionController.new);
