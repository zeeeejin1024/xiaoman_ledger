import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';
import 'package:xiaojia_ledger/core/notification_preferences.dart';

void main() {
  test('loads safe defaults when no notification settings exist', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = NotificationPreferencesRepository(
      await SharedPreferences.getInstance(),
    );

    final value = repo.load();

    expect(value.dailyEnabled, isFalse);
    expect(value.dailyHour, 21);
    expect(value.weeklyEnabled, isTrue);
    expect(value.monthlyEnabled, isTrue);
  });

  test('migrates the legacy daily reminder keys', () async {
    SharedPreferences.setMockInitialValues({
      'reminder_enabled': true,
      'reminder_time': '07:35',
    });
    final repo = NotificationPreferencesRepository(
      await SharedPreferences.getInstance(),
    );

    final value = repo.load();

    expect(value.dailyEnabled, isTrue);
    expect(value.dailyHour, 7);
    expect(value.dailyMinute, 35);
  });

  test('repairs invalid times before saving', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = NotificationPreferencesRepository(prefs);

    await repo.save(
      const NotificationPreferences(
        dailyHour: 99,
        dailyMinute: -1,
        monthlyDay: 30,
      ),
    );
    final value = repo.load();

    expect(value.dailyHour, 23);
    expect(value.dailyMinute, 0);
    expect(value.monthlyDay, 28);
  });
}
