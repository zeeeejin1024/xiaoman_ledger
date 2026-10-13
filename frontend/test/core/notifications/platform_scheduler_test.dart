import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/notification_policy.dart';
import 'package:xiaojia_ledger/core/notifications/notification_audit.dart';
import 'package:xiaojia_ledger/core/notifications/notification_rule.dart';
import 'package:xiaojia_ledger/core/notifications/platform_scheduler.dart';
import 'package:xiaojia_ledger/core/notifications/schedule_plan.dart';

class FakeNotificationGateway implements NotificationPlatformGateway {
  final Set<int> pending = {};
  bool registerPending = true;

  @override
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    bool skipToday = false,
  }) async {
    if (registerPending) pending.addAll(NotificationPolicy.dailyWindowIds);
  }

  @override
  Future<void> cancelDaily() async {
    pending.removeAll(NotificationPolicy.dailyWindowIds);
  }

  @override
  Future<Set<int>> pendingIds() async => pending;
}

void main() {
  const rule = NotificationRule(
    id: 'daily',
    enabled: true,
    time: TimeOfDay(hour: 21, minute: 0),
    kind: NotificationRuleKind.daily,
  );
  final plan = SchedulePlan(
    nextAt: DateTime(2026, 9, 16, 21),
    mode: AndroidScheduleMode.inexactAllowWhileIdle,
    audit: const NotificationAudit(AuditState.scheduled),
  );

  test('reports scheduled only when the expected request exists', () async {
    final gateway = FakeNotificationGateway();
    final store = NotificationAuditStore();
    final scheduler = PlatformScheduler(store, gateway: gateway);

    final audit = await scheduler.apply(rule: rule, plan: plan);

    expect(audit.state, AuditState.scheduled);
    expect(store.last.state, AuditState.scheduled);
  });

  test('pending queue mismatch is reported as failed', () async {
    final gateway = FakeNotificationGateway()..registerPending = false;
    final scheduler = PlatformScheduler(
      NotificationAuditStore(),
      gateway: gateway,
    );

    final audit = await scheduler.apply(rule: rule, plan: plan);

    expect(audit.state, AuditState.failed);
    expect(audit.action, AuditAction.retry);
  });
}
