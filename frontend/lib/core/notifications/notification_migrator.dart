import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_rule.dart';
import 'schedule_plan.dart';

class NotificationMigrationRule {
  final NotificationRule rule;
  const NotificationMigrationRule(this.rule);
}

abstract interface class NotificationMigrationScheduler {
  Future<AuditState> schedule(NotificationMigrationRule rule);
  Future<void> cancelLegacy();
}

class NotificationMigrator {
  static const migratedKey = 'notification_rules_v2_migrated';
  final SharedPreferences prefs;
  final NotificationMigrationScheduler scheduler;

  const NotificationMigrator(this.prefs, this.scheduler);

  Future<bool> run() async {
    if (prefs.getBool(migratedKey) == true) return true;
    final rules = _legacyRules();
    final results = <AuditState>[];
    for (final rule in rules) {
      results.add(await scheduler.schedule(rule));
    }
    final accepted = results.every(
      (state) => state == AuditState.scheduled || state == AuditState.degraded,
    );
    if (!accepted) return false;
    await scheduler.cancelLegacy();
    await prefs.setBool(migratedKey, true);
    return true;
  }

  List<NotificationMigrationRule> _legacyRules() {
    final enabled = prefs.getBool('reminder_enabled') ?? false;
    if (!enabled) return const [];
    final parts = (prefs.getString('reminder_time') ?? '21:00').split(':');
    final hour = int.tryParse(parts.first) ?? 21;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return [
      NotificationMigrationRule(
        NotificationRule(
          id: 'daily',
          enabled: true,
          time: TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59)),
          kind: NotificationRuleKind.daily,
        ),
      ),
    ];
  }
}
