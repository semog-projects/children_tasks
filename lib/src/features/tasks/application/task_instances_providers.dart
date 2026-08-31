import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/firebase/firebase_providers.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/task_instance.dart';
import '../../family/application/family_providers.dart';

/// Meia-noite UTC do dia de hoje (mesma convenção da Cloud Function).
DateTime todayUtcMidnight() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
}

/// Ocorrências de hoje da família atual.
final todayInstancesProvider = StreamProvider<List<TaskInstance>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref
      .watch(taskInstanceRepositoryProvider)
      .watchForDate(family.id, todayUtcMidnight());
});

/// Ocorrências de hoje de uma criança.
final childTodayInstancesProvider =
    StreamProvider.family<List<TaskInstance>, String>((ref, memberId) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref
      .watch(taskInstanceRepositoryProvider)
      .watchForMemberAndDate(family.id, memberId, todayUtcMidnight());
});

/// Pede à Cloud Function que materialize as tarefas de hoje. Best-effort:
/// falha silenciosa (a função agendada cobre o caso normal).
Future<void> requestTodayInstances(WidgetRef ref) async {
  try {
    await ref
        .read(functionsProvider)
        .httpsCallable('generateInstances')
        .call<dynamic>();
  } catch (error) {
    debugPrint('generateInstances (best-effort) falhou: $error');
  }
}
