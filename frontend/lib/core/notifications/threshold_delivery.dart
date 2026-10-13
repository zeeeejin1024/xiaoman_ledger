import '../living_allowance.dart';
import '../living_allowance_repository.dart';
import '../notification_models.dart';
import '../notification_policy.dart';
import '../notification_preferences.dart';

/// Tracks platform acceptance independently from the in-app hint.
/// A receipt means the platform call succeeded, not that the user saw it.
class LivingAlertDelivery {
  final LivingAllowanceRepository repository;
  final Future<bool> Function() isAllowed;
  final Future<void> Function(int threshold, double remaining) send;
  Future<void> _tail = Future<void>.value();

  LivingAlertDelivery({
    required this.repository,
    required this.isAllowed,
    required this.send,
  });

  Future<int?> evaluate({
    required String period,
    required double spentRatio,
    required double remaining,
    required double completeness,
    required bool enabled,
  }) {
    final run = _tail.then((_) async {
      if (!enabled || completeness < .3) return null;
      final notification = LivingAllowanceAlert.next(
        spentRatio: spentRatio,
        alreadySent: repository.notifiedThresholds(period),
      );
      if (notification != null) {
        try {
          if (await isAllowed()) {
            await send(notification.threshold, remaining);
            await repository.markThresholdNotified(
              period,
              notification.threshold,
            );
          }
        } catch (_) {
          // Leave the platform receipt absent so a later refresh can retry.
        }
      }
      final hint = LivingAllowanceAlert.next(
        spentRatio: spentRatio,
        alreadySent: repository.sentThresholds(period),
      );
      if (hint == null) return null;
      await repository.markThresholdSent(period, hint.threshold);
      return hint.threshold;
    });
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }
}

class BudgetAlertDelivery {
  final NotificationPreferencesRepository repository;
  final Future<void> Function(String id, BudgetThreshold threshold) send;
  Future<void> _tail = Future<void>.value();

  BudgetAlertDelivery({required this.repository, required this.send});

  Future<void> evaluate(List<BudgetSnapshot> snapshots, DateTime month) {
    final run = _tail.then((_) async {
      final receipts = repository.thresholdKeys();
      for (final budget in snapshots) {
        if (budget.limit <= 0 ||
            !budget.limit.isFinite ||
            !budget.spent.isFinite) {
          continue;
        }
        String key(BudgetThreshold threshold) =>
            NotificationPolicy.budgetDedupeKey(
              budgetId: budget.id,
              month: month,
              threshold: threshold,
            );
        if (receipts.contains(key(BudgetThreshold.hundredPercent))) continue;
        final threshold = budget.spent >= budget.limit
            ? BudgetThreshold.hundredPercent
            : budget.spent >= budget.limit * .8
            ? BudgetThreshold.eightyPercent
            : null;
        if (threshold == null || receipts.contains(key(threshold))) continue;
        try {
          await send(budget.id, threshold);
          receipts.add(key(threshold));
          if (threshold == BudgetThreshold.hundredPercent) {
            receipts.add(key(BudgetThreshold.eightyPercent));
          }
          await repository.saveThresholdKeys(receipts);
        } catch (_) {
          // Do not fall back to a lower threshold on failure.
        }
      }
    });
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }
}
