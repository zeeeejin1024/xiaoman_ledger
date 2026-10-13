import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_rule.dart';

enum AuditState { disabled, blocked, scheduled, degraded, failed }

enum AuditAction {
  none,
  openNotificationSettings,
  openExactAlarmSettings,
  retry,
}

class NotificationAudit {
  final AuditState state;
  final AuditAction action;
  const NotificationAudit(this.state, [this.action = AuditAction.none]);
}

class SchedulePlan {
  final DateTime? nextAt;
  final AndroidScheduleMode mode;
  final NotificationAudit audit;
  final bool skipToday;
  const SchedulePlan({
    required this.nextAt,
    required this.mode,
    required this.audit,
    this.skipToday = false,
  });
}

class NotificationPlanner {
  const NotificationPlanner();
  SchedulePlan plan({
    required NotificationRule rule,
    required DateTime now,
    required bool notificationsAllowed,
    required bool exactAlarmAllowed,
    bool skipToday = false,
  }) {
    if (!rule.enabled) {
      return const SchedulePlan(
        nextAt: null,
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
        audit: NotificationAudit(AuditState.disabled),
      );
    }
    if (!notificationsAllowed) {
      return const SchedulePlan(
        nextAt: null,
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
        audit: NotificationAudit(
          AuditState.blocked,
          AuditAction.openNotificationSettings,
        ),
      );
    }
    final candidate = DateTime(
      now.year,
      now.month,
      now.day,
      rule.time.hour,
      rule.time.minute,
    );
    final next = candidate.isAfter(now) && !skipToday
        ? candidate
        : candidate.add(const Duration(days: 1));
    if (!exactAlarmAllowed) {
      return SchedulePlan(
        skipToday: skipToday,
        nextAt: next,
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
        audit: const NotificationAudit(AuditState.degraded),
      );
    }
    return SchedulePlan(
      skipToday: skipToday,
      nextAt: next,
      mode: AndroidScheduleMode.exactAllowWhileIdle,
      audit: const NotificationAudit(AuditState.scheduled),
    );
  }
}
