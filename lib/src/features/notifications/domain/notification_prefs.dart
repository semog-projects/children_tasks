/// Preferências de notificação de um responsável. Guardadas em
/// `users/{uid}.notif`.
class NotificationPrefs {
  const NotificationPrefs({
    this.pendingApproval = true,
    this.approvalResult = true,
    this.redemption = true,
    this.dailyReminder = true,
    this.reminderHour = 18,
  });

  final bool pendingApproval;
  final bool approvalResult;
  final bool redemption;
  final bool dailyReminder;

  /// Hora local (0–23) do lembrete diário.
  final int reminderHour;

  factory NotificationPrefs.fromMap(Map<String, dynamic>? map) {
    final m = map ?? const {};
    return NotificationPrefs(
      pendingApproval: m['pendingApproval'] as bool? ?? true,
      approvalResult: m['approvalResult'] as bool? ?? true,
      redemption: m['redemption'] as bool? ?? true,
      dailyReminder: m['dailyReminder'] as bool? ?? true,
      reminderHour: (m['reminderHour'] as num?)?.toInt() ?? 18,
    );
  }

  Map<String, dynamic> toMap() => {
        'pendingApproval': pendingApproval,
        'approvalResult': approvalResult,
        'redemption': redemption,
        'dailyReminder': dailyReminder,
        'reminderHour': reminderHour,
      };

  NotificationPrefs copyWith({
    bool? pendingApproval,
    bool? approvalResult,
    bool? redemption,
    bool? dailyReminder,
    int? reminderHour,
  }) =>
      NotificationPrefs(
        pendingApproval: pendingApproval ?? this.pendingApproval,
        approvalResult: approvalResult ?? this.approvalResult,
        redemption: redemption ?? this.redemption,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        reminderHour: reminderHour ?? this.reminderHour,
      );
}
