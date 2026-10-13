import '../notification_policy.dart';
import '../notifications.dart';
import 'notification_audit.dart';
import 'notification_rule.dart';
import 'schedule_plan.dart';

abstract interface class NotificationPlatformGateway {
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    bool skipToday = false,
  });
  Future<void> cancelDaily();
  Future<Set<int>> pendingIds();
}

class PlatformScheduler {
  final NotificationAuditStore auditStore;
  final NotificationPlatformGateway _gateway;

  PlatformScheduler(this.auditStore, {NotificationPlatformGateway? gateway})
    : _gateway = gateway ?? _NotificationServiceGateway();

  Future<NotificationAudit> apply({
    required NotificationRule rule,
    required SchedulePlan plan,
  }) async {
    if (rule.kind != NotificationRuleKind.daily) {
      return _record(
        const NotificationAudit(AuditState.failed, AuditAction.retry),
      );
    }
    if (plan.audit.state == AuditState.disabled) {
      try {
        await _gateway.cancelDaily();
        return _record(plan.audit);
      } catch (_) {
        return _record(
          const NotificationAudit(AuditState.failed, AuditAction.retry),
        );
      }
    }
    if (plan.audit.state == AuditState.blocked || plan.nextAt == null) {
      return _record(plan.audit, nextAt: plan.nextAt);
    }

    try {
      await _gateway.scheduleDaily(
        hour: rule.time.hour,
        minute: rule.time.minute,
        skipToday: plan.skipToday,
      );
      final pending = await _gateway.pendingIds();
      if (!pending.containsAll(NotificationPolicy.dailyWindowIds)) {
        return _record(
          const NotificationAudit(AuditState.failed, AuditAction.retry),
        );
      }
      return _record(plan.audit, nextAt: plan.nextAt);
    } catch (_) {
      return _record(
        const NotificationAudit(AuditState.failed, AuditAction.retry),
      );
    }
  }

  NotificationAudit _record(NotificationAudit audit, {DateTime? nextAt}) {
    auditStore.record(audit, nextAt: nextAt);
    return audit;
  }
}

class _NotificationServiceGateway implements NotificationPlatformGateway {
  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    bool skipToday = false,
  }) {
    return NotificationService.scheduleDailyReminder(
      hour: hour,
      minute: minute,
      skipToday: skipToday,
    );
  }

  @override
  Future<void> cancelDaily() => NotificationService.cancelDailyWindow();

  @override
  Future<Set<int>> pendingIds() => NotificationService.pendingRequestIds();
}
