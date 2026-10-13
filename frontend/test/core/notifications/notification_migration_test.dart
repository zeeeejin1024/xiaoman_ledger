import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/notifications/notification_migrator.dart';
import 'package:xiaojia_ledger/core/notifications/schedule_plan.dart';

class FakeMigrationScheduler implements NotificationMigrationScheduler {
  AuditState nextResult = AuditState.scheduled;
  int cancelCalls = 0;

  @override
  Future<AuditState> schedule(NotificationMigrationRule rule) async =>
      nextResult;

  @override
  Future<void> cancelLegacy() async => cancelCalls++;
}

void main() {
  test(
    'legacy reminders remain until replacement schedule is verified',
    () async {
      SharedPreferences.setMockInitialValues({
        'reminder_enabled': true,
        'reminder_time': '21:00',
      });
      final prefs = await SharedPreferences.getInstance();
      final scheduler = FakeMigrationScheduler()
        ..nextResult = AuditState.failed;

      await NotificationMigrator(prefs, scheduler).run();

      expect(scheduler.cancelCalls, 0);
      expect(prefs.getBool('notification_rules_v2_migrated'), isNot(true));
    },
  );

  test('successful migration cancels legacy reminders once', () async {
    SharedPreferences.setMockInitialValues({
      'reminder_enabled': true,
      'reminder_time': '21:00',
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = FakeMigrationScheduler();

    await NotificationMigrator(prefs, scheduler).run();

    expect(scheduler.cancelCalls, 1);
    expect(prefs.getBool('notification_rules_v2_migrated'), isTrue);
  });
}
