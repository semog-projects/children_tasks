import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/task_instance.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';

/// Ocorrências aguardando aprovação do responsável (qualquer dia).
final pendingApprovalsProvider = StreamProvider<List<TaskInstance>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(taskInstanceRepositoryProvider).watchPendingApprovals(family.id);
});

/// Marcar como feita (criança) / aprovar / rejeitar (responsável).
class ApprovalController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _familyId => ref.read(currentFamilyIdProvider);
  String get _uid => ref.read(currentUserProvider)!.uid;

  Future<void> markDone(TaskInstance instance) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskInstanceRepositoryProvider).markDone(_familyId, instance),
    );
  }

  Future<void> approve(String instanceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskInstanceRepositoryProvider).approve(_familyId, instanceId, _uid),
    );
  }

  Future<void> reject(String instanceId, {String? reason}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(taskInstanceRepositoryProvider)
          .reject(_familyId, instanceId, _uid, reason: reason),
    );
  }
}

final approvalControllerProvider =
    AsyncNotifierProvider<ApprovalController, void>(ApprovalController.new);
