import 'package:cloud_firestore/cloud_firestore.dart';

enum InvestmentKind {
  deposit,
  withdraw;

  static InvestmentKind fromName(String? value) => InvestmentKind.values
      .firstWhere((k) => k.name == value, orElse: () => InvestmentKind.deposit);
}

enum InvestmentRequestStatus {
  requested,
  approved,
  rejected,
  canceled;

  static InvestmentRequestStatus fromName(String? value) =>
      InvestmentRequestStatus.values.firstWhere((s) => s.name == value,
          orElse: () => InvestmentRequestStatus.requested);
}

/// Pedido de aporte (`deposit`) ou resgate total (`withdraw`) na poupança
/// (issue #73). Criado pela Cloud Function `requestInvestment`; o responsável
/// aprova (`approveInvestment`) ou recusa; a criança cancela enquanto
/// `requested`. Espelha [CashOut].
class InvestmentRequest {
  const InvestmentRequest({
    required this.id,
    required this.memberId,
    this.memberUid,
    required this.kind,
    this.points = 0,
    required this.status,
    this.note,
    this.payoutPoints,
    this.yieldPoints,
    this.requestedByUid,
    this.requestedAt,
    this.decidedByUid,
    this.decidedAt,
  });

  final String id;
  final String memberId;
  final String? memberUid;
  final InvestmentKind kind;

  /// Pontos do aporte (só `deposit`).
  final int points;

  final InvestmentRequestStatus status;

  /// Motivo da recusa.
  final String? note;

  /// Total pago e quanto disso foi rendimento (gravados ao aprovar `withdraw`).
  final int? payoutPoints;
  final int? yieldPoints;

  final String? requestedByUid;
  final DateTime? requestedAt;
  final String? decidedByUid;
  final DateTime? decidedAt;

  bool get isDeposit => kind == InvestmentKind.deposit;
  bool get isWithdraw => kind == InvestmentKind.withdraw;
  bool get isRequested => status == InvestmentRequestStatus.requested;

  factory InvestmentRequest.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return InvestmentRequest(
      id: doc.id,
      memberId: data['memberId'] as String? ?? '',
      memberUid: data['memberUid'] as String?,
      kind: InvestmentKind.fromName(data['kind'] as String?),
      points: (data['points'] as num?)?.toInt() ?? 0,
      status: InvestmentRequestStatus.fromName(data['status'] as String?),
      note: data['note'] as String?,
      payoutPoints: (data['payoutPoints'] as num?)?.toInt(),
      yieldPoints: (data['yieldPoints'] as num?)?.toInt(),
      requestedByUid: data['requestedByUid'] as String?,
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      decidedByUid: data['decidedByUid'] as String?,
      decidedAt: (data['decidedAt'] as Timestamp?)?.toDate(),
    );
  }
}
