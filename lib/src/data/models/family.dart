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
    required this.timezone,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;

  /// uids dos responsáveis — fonte de verdade das Security Rules.
  final List<String> guardianUids;

  /// Exibição dos responsáveis (nome/foto). Mantido em sincronia por
  /// auto-heal quando cada responsável abre o app.
  final List<GuardianRef> guardians;

  /// Fuso IANA, ex.: `America/Sao_Paulo`. Usado na geração de recorrentes.
  final String timezone;

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
      timezone: data['timezone'] as String? ?? 'America/Sao_Paulo',
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

  Map<String, dynamic> toUpdateData() => {
        'name': name,
        'guardianUids': guardianUids,
        'guardians': guardians.map((g) => g.toMap()).toList(),
        'timezone': timezone,
      };

  Family copyWith({
    String? name,
    List<String>? guardianUids,
    List<GuardianRef>? guardians,
    String? timezone,
  }) =>
      Family(
        id: id,
        name: name ?? this.name,
        guardianUids: guardianUids ?? this.guardianUids,
        guardians: guardians ?? this.guardians,
        timezone: timezone ?? this.timezone,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
