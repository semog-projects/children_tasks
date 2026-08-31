import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/member.dart';
import '../../../data/models/redemption.dart';
import '../../../data/models/reward.dart';
import '../../../data/models/task_instance.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../rewards/application/reward_providers.dart';
import '../../tasks/application/task_instances_providers.dart';

/// A criança (member) vinculada ao usuário logado, dentro da família em que
/// ele entra como criança. `null` enquanto carrega ou se o vínculo sumiu.
final currentChildMemberProvider = Provider<Member?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  final family = ref.watch(childFamilyProvider).asData?.value;
  if (uid == null || family == null) return null;
  final children = ref.watch(familyChildrenProvider).asData?.value ?? const [];
  for (final member in children) {
    if (member.linkedUid == uid) return member;
  }
  return null;
});

/// (familyId, uid) da criança logada, ou `null`.
final _childScopeProvider = Provider<({String familyId, String uid})?>((ref) {
  final family = ref.watch(childFamilyProvider).asData?.value;
  final uid = ref.watch(currentUserProvider)?.uid;
  if (family == null || uid == null) return null;
  return (familyId: family.id, uid: uid);
});

/// Tarefas de hoje da própria criança — filtra por `memberUid` (rules #34).
final myChildInstancesProvider = StreamProvider<List<TaskInstance>>((ref) {
  final scope = ref.watch(_childScopeProvider);
  if (scope == null) return Stream.value(const []);
  return ref.watch(taskInstanceRepositoryProvider).watchForMemberUidAndDate(
        scope.familyId,
        scope.uid,
        todayUtcMidnight(),
      );
});

/// Saldo de pontos da própria criança.
final myChildBalanceProvider = StreamProvider<int>((ref) {
  final scope = ref.watch(_childScopeProvider);
  if (scope == null) return Stream.value(0);
  return ref
      .watch(ledgerRepositoryProvider)
      .watchBalanceByUid(scope.familyId, scope.uid);
});

/// Resgates da própria criança.
final myChildRedemptionsProvider = StreamProvider<List<Redemption>>((ref) {
  final scope = ref.watch(_childScopeProvider);
  if (scope == null) return Stream.value(const []);
  return ref
      .watch(redemptionRepositoryProvider)
      .watchForMemberUid(scope.familyId, scope.uid);
});

/// A recompensa ativa mais barata que a criança ainda não consegue pagar.
final myNextRewardProvider =
    Provider<({Reward reward, int missing})?>((ref) {
  final balance = ref.watch(myChildBalanceProvider).asData?.value ?? 0;
  final rewards = ref.watch(activeRewardsProvider).asData?.value ?? const [];
  final upcoming = rewards.where((r) => r.inStock && r.cost > balance).toList()
    ..sort((a, b) => a.cost.compareTo(b.cost));
  if (upcoming.isEmpty) return null;
  final r = upcoming.first;
  return (reward: r, missing: r.cost - balance);
});
