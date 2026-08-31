/// Preferências de notificação, guardadas em `users/{uid}.notif`. Os campos do
/// responsável e os da criança coexistem no mesmo doc; cada tela mostra os
/// seus (issue #35).
class NotificationPrefs {
  const NotificationPrefs({
    this.pendingApproval = true,
    this.approvalResult = true,
    this.redemption = true,
    this.dailyReminder = true,
    this.reminderHour = 18,
    this.taskApproved = true,
    this.taskRejected = true,
    this.rewardDelivered = true,
  });

  // --- responsável ---
  final bool pendingApproval;
  final bool approvalResult;
  final bool redemption;
  final bool dailyReminder;

  /// Hora local (0–23) do lembrete diário.
  final int reminderHour;

  // --- criança ---
  final bool taskApproved;
  final bool taskRejected;
  final bool rewardDelivered;

  factory NotificationPrefs.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const {};
    return NotificationPrefs(
      pendingApproval: m['pendingApproval'] as bool? ?? true,
      approvalResult: m['approvalResult'] as bool? ?? true,
      redemption: m['redemption'] as bool? ?? true,
      dailyReminder: m['dailyReminder'] as bool? ?? true,
      reminderHour: (m['reminderHour'] as num?)?.toInt() ?? 18,
      taskApproved: m['taskApproved'] as bool? ?? true,
      taskRejected: m['taskRejected'] as bool? ?? true,
      rewardDelivered: m['rewardDelivered'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'pendingApproval': pendingApproval,
        'approvalResult': approvalResult,
        'redemption': redemption,
        'dailyReminder': dailyReminder,
        'reminderHour': reminderHour,
        'taskApproved': taskApproved,
        'taskRejected': taskRejected,
        'rewardDelivered': rewardDelivered,
      };

  NotificationPrefs copyWith({
    bool? pendingApproval,
    bool? approvalResult,
    bool? redemption,
    bool? dailyReminder,
    int? reminderHour,
    bool? taskApproved,
    bool? taskRejected,
    bool? rewardDelivered,
  }) =>
      NotificationPrefs(
        pendingApproval: pendingApproval ?? this.pendingApproval,
        approvalResult: approvalResult ?? this.approvalResult,
        redemption: redemption ?? this.redemption,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        reminderHour: reminderHour ?? this.reminderHour,
        taskApproved: taskApproved ?? this.taskApproved,
        taskRejected: taskRejected ?? this.taskRejected,
        rewardDelivered: rewardDelivered ?? this.rewardDelivered,
      );
}
