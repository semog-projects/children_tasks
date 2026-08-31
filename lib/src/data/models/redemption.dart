import 'package:cloud_firestore/cloud_firestore.dart';

enum RedemptionStatus {
  requested,
  delivered,
  canceled;

  static RedemptionStatus fromName(String? value) => RedemptionStatus.values
      .firstWhere((s) => s.name == value, orElse: () => RedemptionStatus.requested);
}

/// Um resgate de recompensa. Criado pela Cloud Function `redeemReward`
/// (débito transacional). O responsável marca como `delivered`.
class Redemption {
  const Redemption({
    required this.id,
    required this.rewardId,
    required this.memberId,
    required this.rewardTitleSnapshot,
    required this.cost,
    required this.status,
    this.requestedAt,
    this.deliveredAt,
    this.deliveredByUid,
  });

  final String id;
  final String rewardId;
  final String memberId;
  final String rewardTitleSnapshot;
  final int cost;
  final RedemptionStatus status;
  final DateTime? requestedAt;
  final DateTime? deliveredAt;
  final String? deliveredByUid;

  bool get isRequested => status == RedemptionStatus.requested;
  bool get isDelivered => status == RedemptionStatus.delivered;

  factory Redemption.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Redemption(
      id: doc.id,
      rewardId: data['rewardId'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      rewardTitleSnapshot: data['rewardTitleSnapshot'] as String? ?? '',
      cost: (data['cost'] as num?)?.toInt() ?? 0,
      status: RedemptionStatus.fromName(data['status'] as String?),
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      deliveredByUid: data['deliveredByUid'] as String?,
    );
  }
}
