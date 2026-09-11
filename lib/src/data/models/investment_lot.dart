import 'package:cloud_firestore/cloud_firestore.dart';

/// Um aporte na poupança da criança (issue #73). Criado/apagado só pela Cloud
/// Function `approveInvestment`. A posição da criança é a soma dos lotes mais o
/// rendimento calculado sobre cada um.
class InvestmentLot {
  const InvestmentLot({
    required this.id,
    required this.points,
    this.memberUid,
    this.createdAt,
  });

  final String id;
  final int points;
  final String? memberUid;
  final DateTime? createdAt;

  factory InvestmentLot.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return InvestmentLot(
      id: doc.id,
      points: (data['points'] as num?)?.toInt() ?? 0,
      memberUid: data['memberUid'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
