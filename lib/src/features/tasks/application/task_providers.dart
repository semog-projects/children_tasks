import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/task.dart';
import '../../family/application/family_providers.dart';

final _activeTasksProvider = StreamProvider<List<Task>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchActive(family.id);
});

final _archivedTasksProvider = StreamProvider<List<Task>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchArchived(family.id);
});

/// Filtros da lista de tarefas.
class TaskFilter {
  const TaskFilter({this.childId, this.category, this.showArchived = false});

  final String? childId;
  final TaskCategory? category;
  final bool showArchived;

  TaskFilter copyWith({
    Object? childId = _keep,
    Object? category = _keep,
    bool? showArchived,
  }) =>
      TaskFilter(
        childId: childId == _keep ? this.childId : childId as String?,
        category: category == _keep ? this.category : category as TaskCategory?,
        showArchived: showArchived ?? this.showArchived,
      );

  static const _keep = Object();
}

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => const TaskFilter();

  void setChild(String? childId) => state = state.copyWith(childId: childId);
  void setCategory(TaskCategory? category) => state = state.copyWith(category: category);
  void toggleArchived() => state = state.copyWith(showArchived: !state.showArchived);
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

/// Tarefas a exibir, já aplicando os filtros.
final visibleTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final filter = ref.watch(taskFilterProvider);
  final source = filter.showArchived ? _archivedTasksProvider : _activeTasksProvider;
  return ref.watch(source).whenData((tasks) {
    return tasks.where((task) {
      if (filter.category != null && task.category != filter.category) {
        return false;
      }
      // Tarefa de uma criança específica não aparece no filtro de outra.
      if (filter.childId != null &&
          task.assigneeMemberId != null &&
          task.assigneeMemberId != filter.childId) {
        return false;
      }
      return true;
    }).toList();
  });
});

/// Cria/edita/arquiva tarefas.
class TaskController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _familyId => ref.read(currentFamilyIdProvider);

  /// Cria (se `task.id` vazio) ou atualiza.
  Future<void> save(Task task) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(taskRepositoryProvider);
      if (task.id.isEmpty) {
        await repo.create(_familyId, task);
      } else {
        await repo.update(_familyId, task);
      }
    });
  }

  Future<void> setActive(String taskId, {required bool active}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).setActive(_familyId, taskId, active: active),
    );
  }
}

final taskControllerProvider =
    AsyncNotifierProvider<TaskController, void>(TaskController.new);
