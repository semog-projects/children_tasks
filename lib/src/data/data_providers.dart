import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/firebase/firebase_providers.dart';
import 'firestore_refs.dart';
import 'repositories/family_repository.dart';
import 'repositories/ledger_repository.dart';
import 'repositories/member_repository.dart';
import 'repositories/redemption_repository.dart';
import 'repositories/reward_repository.dart';
import 'repositories/task_instance_repository.dart';
import 'repositories/task_repository.dart';

final firestoreRefsProvider = Provider<FirestoreRefs>((ref) {
  return FirestoreRefs(ref.watch(firestoreProvider));
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository(ref.watch(firestoreRefsProvider));
});

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(firestoreRefsProvider));
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(firestoreRefsProvider));
});

final taskInstanceRepositoryProvider = Provider<TaskInstanceRepository>((ref) {
  return TaskInstanceRepository(ref.watch(firestoreRefsProvider));
});

final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  return RewardRepository(ref.watch(firestoreRefsProvider));
});

final redemptionRepositoryProvider = Provider<RedemptionRepository>((ref) {
  return RedemptionRepository(ref.watch(firestoreRefsProvider));
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return LedgerRepository(ref.watch(firestoreRefsProvider));
});
