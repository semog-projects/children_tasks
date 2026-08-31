import 'package:cloud_functions/cloud_functions.dart';

/// Um convite recém-gerado (código para compartilhar).
class FamilyInvite {
  const FamilyInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// Um convite em aberto da família (listagem para o responsável).
class PendingInvite {
  const PendingInvite({
    required this.code,
    required this.role,
    required this.expiresAt,
    this.email,
    this.memberId,
  });

  final String code;
  final String role; // 'child' | 'guardian'
  final DateTime expiresAt;
  final String? email;
  final String? memberId;

  bool get isGuardian => role == 'guardian';
}

/// Erro de convite já traduzido para pt-BR.
class InviteException implements Exception {
  const InviteException(this.message);
  final String message;

  @override
  String toString() => 'InviteException: $message';
}

/// Convites de vínculo à família, via Cloud Functions. Ver
/// `functions/src/family/invites.ts`.
abstract interface class InvitesRepository {
  /// Convite para vincular a criança [memberId] da família [familyId].
  Future<FamilyInvite> createChildInvite({
    required String familyId,
    required String memberId,
  });

  /// Convite para adicionar um responsável (opcionalmente amarrado a um
  /// [email], que o aceite exige bater).
  Future<FamilyInvite> createGuardianInvite({
    required String familyId,
    String? email,
  });

  /// Convites ainda não aceitos da família.
  Future<List<PendingInvite>> listInvites(String familyId);

  /// Revoga (apaga) um convite ainda não aceito.
  Future<void> revoke(String code);

  /// Aceita um convite pelo código. O papel do usuário é atualizado no
  /// servidor.
  Future<void> accept(String code);
}

class FirebaseInvitesRepository implements InvitesRepository {
  FirebaseInvitesRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<FamilyInvite> _create(Map<String, dynamic> data) async {
    try {
      final res = await _functions
          .httpsCallable('createFamilyInvite')
          .call<Map<String, dynamic>>(data);
      return FamilyInvite(
        code: res.data['code'] as String,
        expiresAt: DateTime.parse(res.data['expiresAt'] as String),
      );
    } on FirebaseFunctionsException catch (e) {
      throw InviteException(e.message ?? 'Não foi possível gerar o convite.');
    }
  }

  @override
  Future<FamilyInvite> createChildInvite({
    required String familyId,
    required String memberId,
  }) =>
      _create({'familyId': familyId, 'role': 'child', 'memberId': memberId});

  @override
  Future<FamilyInvite> createGuardianInvite({
    required String familyId,
    String? email,
  }) =>
      _create({
        'familyId': familyId,
        'role': 'guardian',
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      });

  @override
  Future<List<PendingInvite>> listInvites(String familyId) async {
    try {
      final res = await _functions
          .httpsCallable('listFamilyInvites')
          .call<Map<String, dynamic>>({'familyId': familyId});
      final list = (res.data['invites'] as List).cast<Map<dynamic, dynamic>>();
      return [
        for (final i in list)
          PendingInvite(
            code: i['code'] as String,
            role: i['role'] as String,
            email: i['email'] as String?,
            memberId: i['memberId'] as String?,
            expiresAt: DateTime.parse(i['expiresAt'] as String),
          ),
      ];
    } on FirebaseFunctionsException catch (e) {
      throw InviteException(e.message ?? 'Não foi possível listar os convites.');
    }
  }

  @override
  Future<void> revoke(String code) async {
    try {
      await _functions
          .httpsCallable('revokeFamilyInvite')
          .call<dynamic>({'code': code});
    } on FirebaseFunctionsException catch (e) {
      throw InviteException(e.message ?? 'Não foi possível revogar o convite.');
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
