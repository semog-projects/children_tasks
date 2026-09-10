import 'package:cloud_firestore/cloud_firestore.dart';

enum CashOutStatus {
  requested,
  approved,
  paid,
  rejected,
  canceled;

  static CashOutStatus fromName(String? value) => CashOutStatus.values
      .firstWhere((s) => s.name == value, orElse: () => CashOutStatus.requested);
}

/// Um pedido de câmbio: a criança troca pontos por dinheiro real (issue #66).
///
/// Fluxo: criança pede (`requested`, não mexe no saldo) → responsável aprova
/// (`approved`, débito transacional feito pela Cloud Function `approveCashOut`)
/// e depois marca como pago (`paid`). Pode ser recusado (`rejected`) ou
/// cancelado pela criança enquanto `requested` (`canceled`).
class CashOut {
  const CashOut({
    required this.id,
    required this.memberId,
    this.memberUid,
    required this.points,
    required this.amountCents,
    required this.rateCents,
    required this.status,
    this.note,
    this.requestedByUid,
    this.requestedAt,
    this.decidedByUid,
    this.decidedAt,
    this.paidByUid,
    this.paidAt,
  });

  final String id;
  final String memberId;
  final String? memberUid;

  /// Pontos a debitar (sempre múltiplo de 5).
  final int points;

  /// Valor em centavos de BRL.
  final int amountCents;

  /// Cotação usada no pedido (centavos por ponto) — snapshot.
  final double rateCents;

  final CashOutStatus status;

  /// Motivo da recusa, quando `rejected`.
  final String? note;

  final String? requestedByUid;
  final DateTime? requestedAt;
  final String? decidedByUid;
  final DateTime? decidedAt;
  final String? paidByUid;
  final DateTime? paidAt;

  bool get isRequested => status == CashOutStatus.requested;
  bool get isApproved => status == CashOutStatus.approved;
  bool get isPaid => status == CashOutStatus.paid;

  /// Valor formatado, ex.: `R$ 3,20`.
  String get amountLabel {
    final reais = amountCents ~/ 100;
    final cents = (amountCents % 100).toString().padLeft(2, '0');
    return 'R\$ $reais,$cents';
  }

  factory CashOut.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return CashOut(
      id: doc.id,
      memberId: data['memberId'] as String? ?? '',
      memberUid: data['memberUid'] as String?,
      points: (data['points'] as num?)?.toInt() ?? 0,
      amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
      rateCents: (data['rateCents'] as num?)?.toDouble() ?? 0,
      status: CashOutStatus.fromName(data['status'] as String?),
      note: data['note'] as String?,
      requestedByUid: data['requestedByUid'] as String?,
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      decidedByUid: data['decidedByUid'] as String?,
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
      paidByUid: data['paidByUid'] as String?,
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
    );
  }
}
