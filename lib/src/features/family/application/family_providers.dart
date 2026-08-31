import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/data_providers.dart';
import '../../../data/models/family.dart';
import '../../../data/models/member.dart';
import '../../auth/application/auth_providers.dart';

/// Famílias em que o usuário logado é responsável.
final guardianFamiliesProvider = StreamProvider<List<Family>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(familyRepositoryProvider).watchForGuardian(user.uid);
});

/// Família em que o usuário logado entra como criança (login próprio), ou
/// `null`. Ver [FamilyRepository.watchForChild].
final childFamilyProvider = StreamProvider<Family?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref
      .watch(familyRepositoryProvider)
      .watchForChild(user.uid)
      .map((families) => families.isEmpty ? null : families.first);
});

/// Família ativa da sessão. O papel de responsável tem prioridade; quem não é
/// responsável de nenhuma cai na família onde é criança. `null` = logado mas
/// sem família (dispara a tela de boas-vindas). Base para tarefas, recompensas,
/// pontos e sync — serve os dois papéis.
final currentFamilyProvider = Provider<AsyncValue<Family?>>((ref) {
  final guardian = ref.watch(guardianFamiliesProvider);
  return guardian.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue<Family?>.error(e, st),
    data: (families) => families.isNotEmpty
        ? AsyncValue.data(families.first)
        : ref.watch(childFamilyProvider),
  );
});

/// Id da família atual (lança se não houver — use só depois do onboarding).
final currentFamilyIdProvider = Provider<String>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) {
    throw StateError('currentFamilyIdProvider lido sem família ativa');
  }
  return family.id;
});

/// Crianças da família atual.
final familyChildrenProvider = StreamProvider<List<Member>>((ref) {
  final family = ref.watch(currentFamilyProvider).asData?.value;
  if (family == null) return Stream.value(const []);
  return ref.watch(memberRepositoryProvider).watchChildren(family.id);
});

GuardianRef _guardianRefFromUser(User user) => GuardianRef(
      uid: user.uid,
      displayName: user.displayName?.trim().isNotEmpty ?? false
          ? user.displayName!.trim()
          : 'Responsável',
      photoUrl: user.photoURL,
    );

/// Cria/edita a família e gerencia responsáveis.
class FamilyController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createFamily({required String name, required String timezone}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw StateError('sem usuário autenticado');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(familyRepositoryProvider).create(
            Family(id: '', name: name.trim(), guardianUids: const [], timezone: timezone),
            creator: _guardianRefFromUser(user),
          );
    });
  }

  Future<void> rename(String name) async {
    final family = ref.read(currentFamilyProvider).asData?.value;
    if (family == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(familyRepositoryProvider).update(family.copyWith(name: name.trim())),
    );
  }

  Future<void> setTimezone(String timezone) async {
    final family = ref.read(currentFamilyProvider).asData?.value;
    if (family == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(familyRepositoryProvider).update(family.copyWith(timezone: timezone)),
    );
  }

  Future<void> addGuardianByUid(String uid) async {
    final family = ref.read(currentFamilyProvider).asData?.value;
    if (family == null) return;
    final clean = uid.trim();
    if (clean.isEmpty || family.guardianUids.contains(clean)) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(familyRepositoryProvider).addGuardian(family.id, clean),
    );
  }

  /// Mantém o nome/foto do responsável logado atualizado no doc da família.
  Future<void> healOwnProfile() async {
    final user = ref.read(currentUserProvider);
    final family = ref.read(currentFamilyProvider).asData?.value;
    if (user == null || family == null) return;
    await ref
        .read(familyRepositoryProvider)
        .healGuardianProfile(family, _guardianRefFromUser(user));
  }
}

final familyControllerProvider =
    AsyncNotifierProvider<FamilyController, void>(FamilyController.new);

/// CRUD de crianças na família atual.
class MemberController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  String get _familyId => ref.read(currentFamilyIdProvider);

  Future<void> addChild({
    required String displayName,
    String? avatarColor,
    DateTime? birthDate,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(memberRepositoryProvider).add(
            _familyId,
            Member(
              id: '',
              type: MemberType.child,
              displayName: displayName.trim(),
              avatarColor: avatarColor,
              birthDate: birthDate,
            ),
          );
    });
  }

  Future<void> updateChild(Member member) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(memberRepositoryProvider).update(_familyId, member),
    );
  }

  Future<void> removeChild(String memberId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(memberRepositoryProvider).remove(_familyId, memberId),
    );
  }
}

final memberControllerProvider =
    AsyncNotifierProvider<MemberController, void>(MemberController.new);
