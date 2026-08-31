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

  final List<({String familyId, String memberId})> createdInvites = [];
  final List<String> acceptedCodes = [];

  @override
  Future<FamilyInvite> createChildInvite({
    required String familyId,
    required String memberId,
  }) async {
    createdInvites.add((familyId: familyId, memberId: memberId));
    return _invite;
  }

  @override
  Future<void> accept(String code) async {
    acceptedCodes.add(code);
    await onAccept?.call(code);
  }
}
