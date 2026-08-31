import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskInstanceStatus {
  pending,
  awaitingApproval,
  approved,
  rejected;

  static TaskInstanceStatus fromName(String? value) => TaskInstanceStatus.values
      .firstWhere((s) => s.name == value, orElse: () => TaskInstanceStatus.pending);
}

/// Ocorrência de uma tarefa para uma criança num dia.
class TaskInstance {
  const TaskInstance({
    required this.id,
    required this.taskId,
    required this.memberId,
    required this.date,
    required this.status,
    required this.titleSnapshot,
    required this.pointsSnapshot,
    required this.requiresApproval,
    this.completedAt,
    this.reviewedByUid,
    this.reviewedAt,
    this.rejectionReason,
    this.pointsAwarded,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String taskId;
  final String memberId;

  /// Dia devido (00:00 no fuso da família).
  final DateTime date;

  final TaskInstanceStatus status;
  final String titleSnapshot;
  final int pointsSnapshot;
  final bool requiresApproval;
  final DateTime? completedAt;
  final String? reviewedByUid;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final int? pointsAwarded;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == TaskInstanceStatus.pending;
  bool get isAwaitingApproval => status == TaskInstanceStatus.awaitingApproval;
  bool get isApproved => status == TaskInstanceStatus.approved;

  factory TaskInstance.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return TaskInstance(
      id: doc.id,
      taskId: data['taskId'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      status: TaskInstanceStatus.fromName(data['status'] as String?),
      titleSnapshot: data['titleSnapshot'] as String? ?? '',
      pointsSnapshot: (data['pointsSnapshot'] as num?)?.toInt() ?? 0,
      requiresApproval: data['requiresApproval'] as bool? ?? true,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      reviewedByUid: data['reviewedByUid'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'] as String?,
      pointsAwarded: (data['pointsAwarded'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Dados para criar uma ocorrência (usado por #10 e pela criação de tarefa `once`).
  static Map<String, dynamic> createData({
    required String taskId,
    required String memberId,
    required DateTime date,
    required String titleSnapshot,
    required int pointsSnapshot,
    required bool requiresApproval,
  }) =>
      {
        'taskId': taskId,
        'memberId': memberId,
        'date': Timestamp.fromDate(date),
        'status': TaskInstanceStatus.pending.name,
        'titleSnapshot': titleSnapshot,
        'pointsSnapshot': pointsSnapshot,
        'requiresApproval': requiresApproval,
      };
}
