import 'package:childrentasks/src/features/family/data/invites_repository.dart';

/// [InvitesRepository] em memória para testes de widget. O comportamento de
/// `accept` (que no real muda o papel do usuário no servidor) é injetado.
class FakeInvitesRepository implements InvitesRepository {
  FakeInvitesRepository({this.onAccept, FamilyInvite? invite})
      : _invite = invite ??
            FamilyInvite(
              code: 'TESTCODE',
              expiresAt: DateTime.now().add(const Duration(days: 7)),
            );

  final FamilyInvite _invite;

  /// Roda em `accept`. Lança [InviteException] para simular código inválido.
  final Future<void> Function(String code)? onAccept;

  final List<({String familyId, String memberId})> createdChildInvites = [];
  final List<({String familyId, String? email})> createdGuardianInvites = [];
  final List<String> acceptedCodes = [];
  final List<String> revokedCodes = [];
  List<PendingInvite> pending = const [];

  @override
  Future<FamilyInvite> createChildInvite({
    required String familyId,
    required String memberId,
  }) async {
    createdChildInvites.add((familyId: familyId, memberId: memberId));
    return _invite;
  }

  @override
  Future<FamilyInvite> createGuardianInvite({
    required String familyId,
    String? email,
  }) async {
    createdGuardianInvites.add((familyId: familyId, email: email));
    return _invite;
  }

  @override
  Future<List<PendingInvite>> listInvites(String familyId) async => pending;

  @override
  Future<void> revoke(String code) async {
    revokedCodes.add(code);
    pending = pending.where((i) => i.code != code).toList();
  }

  @override
  Future<void> accept(String code) async {
    acceptedCodes.add(code);
    await onAccept?.call(code);
  }
}
