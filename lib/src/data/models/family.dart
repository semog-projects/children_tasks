import 'package:cloud_firestore/cloud_firestore.dart';

/// Uma família. Raiz de tudo: membros, tarefas, recompensas, ledger.
class Family {
  const Family({
    required this.id,
    required this.name,
    required this.guardianUids,
    required this.timezone,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> guardianUids;

  /// Fuso IANA, ex.: `America/Sao_Paulo`. Usado na geração de recorrentes.
  final String timezone;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Family.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Family(
      id: doc.id,
      name: data['name'] as String? ?? '',
      guardianUids: (data['guardianUids'] as List<dynamic>? ?? const [])
          .cast<String>(),
      timezone: data['timezone'] as String? ?? 'America/Sao_Paulo',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Dados para `create` (o repositório adiciona os timestamps de servidor).
  Map<String, dynamic> toCreateData(String creatorUid) => {
        'name': name,
        'guardianUids': guardianUids.isEmpty ? [creatorUid] : guardianUids,
        'timezone': timezone,
      };

  Map<String, dynamic> toUpdateData() => {
        'name': name,
        'guardianUids': guardianUids,
        'timezone': timezone,
      };

  Family copyWith({String? name, List<String>? guardianUids, String? timezone}) =>
      Family(
        id: id,
        name: name ?? this.name,
        guardianUids: guardianUids ?? this.guardianUids,
        timezone: timezone ?? this.timezone,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
