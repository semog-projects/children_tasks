import 'package:cloud_firestore/cloud_firestore.dart';

/// Dados de exibição de um responsável, desnormalizados no doc da família
/// (o `users/{uid}` só é legível pelo próprio dono).
class GuardianRef {
  const GuardianRef({required this.uid, required this.displayName, this.photoUrl});

  final String uid;
  final String displayName;
  final String? photoUrl;

  factory GuardianRef.fromMap(Map<String, dynamic> map) => GuardianRef(
        uid: map['uid'] as String? ?? '',
        displayName: map['displayName'] as String? ?? 'Responsável',
        photoUrl: map['photoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': ?photoUrl,
      };

  GuardianRef copyWith({String? displayName, String? photoUrl}) => GuardianRef(
        uid: uid,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}

/// Uma família. Raiz de tudo: membros, tarefas, recompensas, ledger.
class Family {
  const Family({
    required this.id,
    required this.name,
    required this.guardianUids,
    this.guardians = const [],
    this.childUids = const [],
    required this.timezone,
    this.pointValueCents = defaultPointValueCents,
    this.createdAt,
    this.updatedAt,
  });

  /// Cotação padrão: R$ 0,016 por ponto (100 pts = R$ 1,60).
  static const double defaultPointValueCents = 1.6;

  final String id;
  final String name;

  /// uids dos responsáveis — fonte de verdade das Security Rules.
  final List<String> guardianUids;

  /// uids das crianças com login próprio vinculado (issue #33). Espelho de
  /// `members/{id}.linkedUid` para `type == 'child'`; gerido pelas Functions.
  /// Fonte de verdade das rules para o papel "criança".
  final List<String> childUids;

  /// Exibição dos responsáveis (nome/foto). Mantido em sincronia por
  /// auto-heal quando cada responsável abre o app.
  final List<GuardianRef> guardians;

  /// Fuso IANA, ex.: `America/Sao_Paulo`. Usado na geração de recorrentes.
  final String timezone;

  /// Quanto vale um ponto no câmbio, em centavos de BRL (issue #66). Editável
  /// pelo responsável na tela de Família; a Cloud Function lê deste doc.
  final double pointValueCents;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  GuardianRef? guardianFor(String uid) {
    for (final g in guardians) {
      if (g.uid == uid) return g;
    }
    return null;
  }

  factory Family.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Family(
      id: doc.id,
      name: data['name'] as String? ?? '',
      guardianUids:
          (data['guardianUids'] as List<dynamic>? ?? const []).cast<String>(),
      guardians: (data['guardians'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(GuardianRef.fromMap)
          .toList(),
      childUids:
          (data['childUids'] as List<dynamic>? ?? const []).cast<String>(),
      timezone: data['timezone'] as String? ?? 'America/Sao_Paulo',
      pointValueCents:
          (data['pointValueCents'] as num?)?.toDouble() ?? defaultPointValueCents,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Dados para `create` (o repositório adiciona os timestamps de servidor).
  Map<String, dynamic> toCreateData(GuardianRef creator) => {
        'name': name,
        'guardianUids': [creator.uid],
        'guardians': [creator.toMap()],
        'timezone': timezone,
      };

  /// `childUids` fica de fora de propósito: é gerido pelas Cloud Functions
  /// (arrayUnion no vínculo da criança); um `update()` parcial não o toca.
  Map<String, dynamic> toUpdateData() => {
        'name': name,
        'guardianUids': guardianUids,
        'guardians': guardians.map((g) => g.toMap()).toList(),
        'timezone': timezone,
        'pointValueCents': pointValueCents,
      };

  Family copyWith({
    String? name,
    List<String>? guardianUids,
    List<GuardianRef>? guardians,
    List<String>? childUids,
    String? timezone,
    double? pointValueCents,
  }) =>
      Family(
        id: id,
        name: name ?? this.name,
        guardianUids: guardianUids ?? this.guardianUids,
        guardians: guardians ?? this.guardians,
        childUids: childUids ?? this.childUids,
        timezone: timezone ?? this.timezone,
        pointValueCents: pointValueCents ?? this.pointValueCents,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
