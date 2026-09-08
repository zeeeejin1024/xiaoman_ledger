import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';
import 'package:xiaojia_ledger/core/notification_policy.dart';

void main() {
  group('NotificationPolicy daily schedules', () {
    test(
      'creates a rolling window and skips a time that already passed today',
      () {
        final now = DateTime(2026, 9, 8, 21, 30);

        final dates = NotificationPolicy.dailyOccurrences(
          now: now,
          hour: 21,
          minute: 0,
          days: 3,
        );

        expect(dates, [
          DateTime(2026, 9, 9, 21),
          DateTime(2026, 9, 10, 21),
          DateTime(2026, 9, 11, 21),
        ]);
      },
    );

    test('keeps today when the selected time is still ahead', () {
      final dates = NotificationPolicy.dailyOccurrences(
        now: DateTime(2026, 9, 8, 20),
        hour: 21,
        minute: 0,
        days: 2,
      );

      expect(dates, [DateTime(2026, 9, 8, 21), DateTime(2026, 9, 9, 21)]);
    });

    test('calculates the next weekly and monthly report occurrence', () {
      final now = DateTime(2026, 9, 8, 10);
      expect(
        NotificationPolicy.nextWeeklyOccurrence(
          now: now,
          weekday: DateTime.monday,
          hour: 9,
          minute: 0,
        ),
        DateTime(2026, 9, 14, 9),
      );
      expect(
        NotificationPolicy.nextMonthlyOccurrence(
          now: now,
          day: 1,
          hour: 9,
          minute: 0,
        ),
        DateTime(2026, 10, 1, 9),
      );
    });
  });

  group('NotificationPolicy IDs and thresholds', () {
    test('keeps IDs in their documented non-overlapping ranges', () {
      final dates = NotificationPolicy.dailyOccurrences(
        now: DateTime(2026, 9, 8, 20),
        hour: 21,
        minute: 0,
        days: 90,
      );
      final ids = dates.map(NotificationPolicy.dailyIdForDate).toSet();

      expect(ids.length, 90);
      expect(ids.every((id) => id >= 100000 && id <= 100089), isTrue);
      expect(NotificationPolicy.weeklyReportId, 200000);
      expect(NotificationPolicy.monthlyReportId, 200001);
    });

    test('emits each budget threshold only when it is crossed', () {
      expect(
        NotificationPolicy.crossedBudgetThresholds(
          previousSpent: 70,
          currentSpent: 85,
          limit: 100,
        ),
        {BudgetThreshold.eightyPercent},
      );
      expect(
        NotificationPolicy.crossedBudgetThresholds(
          previousSpent: 85,
          currentSpent: 120,
          limit: 100,
        ),
        {BudgetThreshold.hundredPercent},
      );
      expect(
        NotificationPolicy.crossedBudgetThresholds(
          previousSpent: 100,
          currentSpent: 101,
          limit: 100,
        ),
        isEmpty,
      );
    });

    test('builds a month-scoped budget dedupe key', () {
      expect(
        NotificationPolicy.budgetDedupeKey(
          budgetId: 'wallet:food',
          month: DateTime(2026, 9, 8),
          threshold: BudgetThreshold.eightyPercent,
        ),
        '2026-09|wallet:food|80',
      );
    });
  });

  test('filters invalid and past deal reminders', () {
    final now = DateTime(2026, 9, 8, 10);
    final deals = [
      DealReminder(
        id: 1,
        title: '过去',
        description: '',
        remindDate: DateTime(2026, 9, 7),
      ),
      DealReminder(
        id: 2,
        title: '今天',
        description: '',
        remindDate: DateTime(2026, 9, 8),
      ),
      DealReminder(
        id: 3,
        title: '未来',
        description: '',
        remindDate: DateTime(2026, 9, 9),
      ),
    ];

    expect(NotificationPolicy.futureDeals(deals, now), [deals[1], deals[2]]);
  });
}
