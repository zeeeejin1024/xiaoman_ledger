import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/living_allowance.dart';
import 'package:xiaojia_ledger/core/living_allowance_repository.dart';
import 'package:xiaojia_ledger/core/notification_preferences.dart';
import 'package:xiaojia_ledger/core/notification_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a completed high threshold does not trigger lower alerts later', () {
    expect(
      LivingAllowanceAlert.next(spentRatio: 1.1, alreadySent: {100}),
      isNull,
    );
    expect(
      LivingAllowanceAlert.next(spentRatio: .95, alreadySent: {90}),
      isNull,
    );
    expect(
      LivingAllowanceAlert.next(spentRatio: 1.1, alreadySent: {90})?.threshold,
      100,
    );
  });

  test(
    'daily suppression survives reload but only applies on its date',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime(2026, 9, 23, 12);
      await NotificationPreferencesRepository(prefs).markRecordedOn(today);
      final reloaded = NotificationPreferencesRepository(prefs);
      expect(reloaded.hasRecordedOn(today), isTrue);
      expect(reloaded.hasRecordedOn(DateTime(2026, 9, 24)), isFalse);
    },
  );

  test('daily window skips today and reserves distinct cancellable IDs', () {
    final dates = NotificationPolicy.dailyOccurrences(
      now: DateTime(2026, 9, 23, 12),
      hour: 21,
      minute: 0,
      days: NotificationPolicy.dailyWindowDays,
      skipToday: true,
    );
    expect(dates.first, DateTime(2026, 9, 24, 21));
    expect(dates.length, 30);
    expect(NotificationPolicy.dailyWindowIds.toSet().length, 30);
    expect(
      NotificationPolicy.dailyWindowIds,
      contains(NotificationPolicy.dailyReminderId),
    );
  });

  test('living notification and in-app hint have separate receipts', () async {
    final repo = LivingAllowanceRepository(
      await SharedPreferences.getInstance(),
    );
    await repo.markThresholdSent('2026-09-01', 90);
    expect(repo.sentThresholds('2026-09-01'), contains(90));
    expect(repo.notifiedThresholds('2026-09-01'), isEmpty);
    await repo.markThresholdNotified('2026-09-01', 90);
    expect(repo.notifiedThresholds('2026-09-01'), contains(90));
  });
}
