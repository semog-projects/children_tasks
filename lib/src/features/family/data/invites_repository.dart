import 'package:cloud_functions/cloud_functions.dart';

/// Um convite recém-gerado para vincular uma criança.
class FamilyInvite {
  const FamilyInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// Erro de convite já traduzido para pt-BR.
class InviteException implements Exception {
  const InviteException(this.message);
  final String message;

  @override
  String toString() => 'InviteException: $message';
}

/// Convites de vínculo à família, via Cloud Functions (`createFamilyInvite` /
/// `acceptFamilyInvite`). Ver `functions/src/family/invites.ts`.
abstract interface class InvitesRepository {
  /// Gera um convite para a criança [memberId] da família [familyId].
  Future<FamilyInvite> createChildInvite({
    required String familyId,
    required String memberId,
  });

  /// Aceita um convite pelo código. O papel do usuário (`childUids` /
  /// `guardianUids`) é atualizado no servidor.
  Future<void> accept(String code);
}

class FirebaseInvitesRepository implements InvitesRepository {
  FirebaseInvitesRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<FamilyInvite> createChildInvite({
    required String familyId,
    required String memberId,
  }) async {
    try {
      final res = await _functions
          .httpsCallable('createFamilyInvite')
          .call<Map<String, dynamic>>({
        'familyId': familyId,
        'role': 'child',
        'memberId': memberId,
      });
      return FamilyInvite(
        code: res.data['code'] as String,
        expiresAt: DateTime.parse(res.data['expiresAt'] as String),
      );
    } on FirebaseFunctionsException catch (e) {
      throw InviteException(e.message ?? 'Não foi possível gerar o convite.');
    }
  }

  @override
  Future<void> accept(String code) async {
    try {
      await _functions
          .httpsCallable('acceptFamilyInvite')
          .call<dynamic>({'code': code.trim()});
    } on FirebaseFunctionsException catch (e) {
      throw InviteException(switch (e.code) {
        'not-found' => 'Código não encontrado. Confira e tente de novo.',
        'failed-precondition' =>
          e.message ?? 'Este convite não pode mais ser usado.',
        'permission-denied' => e.message ?? 'Este convite não é para esta conta.',
        _ => e.message ?? 'Não foi possível entrar com este código.',
      });
    }
  }
}
