import 'package:cloud_firestore/cloud_firestore.dart';

enum LedgerEntryType {
  earn,
  redeem,
  adjustment;

  static LedgerEntryType fromName(String? value) => LedgerEntryType.values
      .firstWhere((t) => t.name == value, orElse: () => LedgerEntryType.adjustment);
}

enum LedgerSourceType {
  taskInstance,
  reward,
  manual;

  static LedgerSourceType fromName(String? value) => LedgerSourceType.values
      .firstWhere((t) => t.name == value, orElse: () => LedgerSourceType.manual);
}

/// Lançamento de pontos (append-only). Saldo = soma de `points` por criança.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.memberId,
    required this.type,
    required this.points,
    required this.sourceType,
    this.sourceId,
    this.note,
    required this.createdByUid,
    this.createdAt,
  });

  final String id;
  final String memberId;
  final LedgerEntryType type;

  /// Com sinal: `earn` > 0, `redeem` < 0.
  final int points;

  final LedgerSourceType sourceType;
  final String? sourceId;
  final String? note;
  final String createdByUid;
  final DateTime? createdAt;

  factory LedgerEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return LedgerEntry(
      id: doc.id,
      memberId: data['memberId'] as String? ?? '',
      type: LedgerEntryType.fromName(data['type'] as String?),
      points: (data['points'] as num?)?.toInt() ?? 0,
      sourceType: LedgerSourceType.fromName(data['sourceType'] as String?),
      sourceId: data['sourceId'] as String?,
      note: data['note'] as String?,
      createdByUid: data['createdByUid'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> createData({
    required String memberId,
    required LedgerEntryType type,
    required int points,
    required LedgerSourceType sourceType,
    String? sourceId,
    String? note,
    required String createdByUid,
  }) =>
      {
        'memberId': memberId,
        'type': type.name,
        'points': points,
        'sourceType': sourceType.name,
        'sourceId': ?sourceId,
        'note': ?note,
        'createdByUid': createdByUid,
      };
}
