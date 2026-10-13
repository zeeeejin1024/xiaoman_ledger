import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/notifications/notification_rule.dart';
import 'package:xiaojia_ledger/core/notifications/schedule_plan.dart';

void main() {
  final rule = NotificationRule(
    id: 'daily',
    enabled: true,
    time: const TimeOfDay(hour: 21, minute: 0),
    kind: NotificationRuleKind.daily,
  );
  test('enabled rule with permission creates an auditable occurrence', () {
    final plan = const NotificationPlanner().plan(
      rule: rule,
      now: DateTime(2026, 9, 15, 20),
      notificationsAllowed: true,
      exactAlarmAllowed: true,
    );
    expect(plan.nextAt, DateTime(2026, 9, 15, 21));
    expect(plan.audit.state, AuditState.scheduled);
    expect(plan.mode, AndroidScheduleMode.exactAllowWhileIdle);
  });
  test('missing permission is blocked', () {
    final plan = const NotificationPlanner().plan(
      rule: rule,
      now: DateTime(2026, 9, 15, 20),
      notificationsAllowed: false,
      exactAlarmAllowed: true,
    );
    expect(plan.audit.state, AuditState.blocked);
  });
}
