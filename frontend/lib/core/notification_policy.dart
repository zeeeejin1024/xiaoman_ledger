import 'notification_models.dart';

class NotificationPolicy {
  static const weeklyReportId = 200000;
  static const monthlyReportId = 200001;
  static const testScheduledId = 200098;
  static const testImmediateId = 200099;
  static const dailyBaseId = 100000;
  static const dailyReminderId = 100090;
  static const dailyWindowDays = 30;
  static Iterable<int> get dailyWindowIds =>
      List.generate(dailyWindowDays, (index) => dailyReminderId + index);
  static const dealBaseId = 300000;
  static const budgetBaseId = 400000;

  static Iterable<int> get legacyDailyIds sync* {
    for (var id = dailyBaseId; id < dailyReminderId; id++) {
      yield id;
    }
  }

  static List<DateTime> dailyOccurrences({
    required DateTime now,
    required int hour,
    required int minute,
    int days = 90,
    bool skipToday = false,
  }) {
    final first = DateTime(now.year, now.month, now.day, hour, minute);
    var cursor = first.isAfter(now) && !skipToday
        ? first
        : first.add(const Duration(days: 1));
    return List<DateTime>.generate(days, (index) {
      final result = cursor.add(Duration(days: index));
      return DateTime(result.year, result.month, result.day, hour, minute);
    });
  }

  static int dailyIdForDate(DateTime date) {
    final epochDay = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(2024, 1, 1)).inDays;
    return dailyBaseId + (epochDay % 90);
  }

  static DateTime nextWeeklyOccurrence({
    required DateTime now,
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final candidate = DateTime(now.year, now.month, now.day, hour, minute);
    var daysAhead = (weekday - now.weekday + 7) % 7;
    if (daysAhead == 0 && !candidate.isAfter(now)) daysAhead = 7;
    return candidate.add(Duration(days: daysAhead));
  }

  static DateTime nextMonthlyOccurrence({
    required DateTime now,
    required int day,
    required int hour,
    required int minute,
  }) {
    final safeDay = day.clamp(1, 28);
    var candidate = DateTime(now.year, now.month, safeDay, hour, minute);
    if (!candidate.isAfter(now)) {
      candidate = DateTime(now.year, now.month + 1, safeDay, hour, minute);
    }
    return candidate;
  }

  static Set<BudgetThreshold> crossedBudgetThresholds({
    required double previousSpent,
    required double currentSpent,
    required double limit,
  }) {
    if (limit <= 0 || currentSpent < previousSpent) return {};
    final previousRatio = previousSpent / limit;
    final currentRatio = currentSpent / limit;
    return {
      if (previousRatio < .8 && currentRatio >= .8)
        BudgetThreshold.eightyPercent,
      if (previousRatio < 1.0 && currentRatio >= 1.0)
        BudgetThreshold.hundredPercent,
    };
  }

  static String budgetDedupeKey({
    required String budgetId,
    required DateTime month,
    required BudgetThreshold threshold,
  }) {
    final value = threshold == BudgetThreshold.eightyPercent ? 80 : 100;
    return '${month.year}-${month.month.toString().padLeft(2, '0')}|$budgetId|$value';
  }

  static int dealId(int id) => dealBaseId + (id.abs() % 100000);

  static int budgetId(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0xFFFF;
    }
    return budgetBaseId + hash;
  }

  static List<DealReminder> futureDeals(
    List<DealReminder> deals,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    return deals.where((deal) {
      final date = DateTime(
        deal.remindDate.year,
        deal.remindDate.month,
        deal.remindDate.day,
      );
      return !date.isBefore(today);
    }).toList();
  }
}
