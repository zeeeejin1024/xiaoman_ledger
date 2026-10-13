import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/living_allowance_repository.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';
import 'package:xiaojia_ledger/core/notification_preferences.dart';
import 'package:xiaojia_ledger/core/notifications/threshold_delivery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'denied living notification retries later without repeating in-app hint',
    () async {
      final repo = LivingAllowanceRepository(
        await SharedPreferences.getInstance(),
      );
      var allowed = false;
      final sent = <int>[];
      final delivery = LivingAlertDelivery(
        repository: repo,
        isAllowed: () async => allowed,
        send: (threshold, remaining) async => sent.add(threshold),
      );
      expect(
        await delivery.evaluate(
          period: 'p',
          spentRatio: .95,
          remaining: 5,
          completeness: 1,
          enabled: true,
        ),
        90,
      );
      expect(repo.notifiedThresholds('p'), isEmpty);
      allowed = true;
      expect(
        await delivery.evaluate(
          period: 'p',
          spentRatio: .95,
          remaining: 5,
          completeness: 1,
          enabled: true,
        ),
        isNull,
      );
      expect(sent, [90]);
      expect(repo.notifiedThresholds('p'), {90});
    },
  );

  test('disabled living rule leaves both receipt channels untouched', () async {
    final repo = LivingAllowanceRepository(
      await SharedPreferences.getInstance(),
    );
    final delivery = LivingAlertDelivery(
      repository: repo,
      isAllowed: () async => throw StateError('must not request permission'),
      send: (_, _) async => fail('must not send'),
    );
    expect(
      await delivery.evaluate(
        period: 'p',
        spentRatio: 1.2,
        remaining: -20,
        completeness: 1,
        enabled: false,
      ),
      isNull,
    );
    expect(repo.notifiedThresholds('p'), isEmpty);
    expect(repo.sentThresholds('p'), isEmpty);
  });

  test(
    'failed living send retries and concurrent refreshes do not duplicate',
    () async {
      final repo = LivingAllowanceRepository(
        await SharedPreferences.getInstance(),
      );
      var attempts = 0;
      final gate = Completer<void>();
      final delivery = LivingAlertDelivery(
        repository: repo,
        isAllowed: () async => true,
        send: (_, _) async {
          attempts++;
          if (attempts == 1) throw StateError('platform failed');
          await gate.future;
        },
      );
      Future<int?> evaluate() => delivery.evaluate(
        period: 'p',
        spentRatio: 1.2,
        remaining: -20,
        completeness: 1,
        enabled: true,
      );
      expect(await evaluate(), 100);
      expect(repo.notifiedThresholds('p'), isEmpty);
      final a = evaluate();
      final b = evaluate();
      gate.complete();
      await Future.wait([a, b]);
      expect(attempts, 2);
      expect(await evaluate(), isNull);
      expect(attempts, 2);
    },
  );

  test(
    'budget sends only highest unsent threshold and retries failure',
    () async {
      final repo = NotificationPreferencesRepository(
        await SharedPreferences.getInstance(),
      );
      final attempts = <BudgetThreshold>[];
      var failSend = true;
      final delivery = BudgetAlertDelivery(
        repository: repo,
        send: (id, threshold) async {
          expect(id, 'wallet:17');
          attempts.add(threshold);
          if (failSend) throw StateError('platform failed');
        },
      );
      final now = DateTime.now();
      const wallets = [
        BudgetSnapshot(id: 'wallet:17', label: '餐饮', spent: 120, limit: 100),
      ];
      await delivery.evaluate(wallets, now);
      expect(repo.thresholdKeys(), isEmpty);
      expect(attempts, [BudgetThreshold.hundredPercent]);
      failSend = false;
      await delivery.evaluate(wallets, now);
      await delivery.evaluate(wallets, now);
      expect(attempts, [
        BudgetThreshold.hundredPercent,
        BudgetThreshold.hundredPercent,
      ]);
      expect(repo.thresholdKeys().length, 2);
    },
  );

  test(
    'legacy high budget receipt suppresses lower alert after refund',
    () async {
      final repo = NotificationPreferencesRepository(
        await SharedPreferences.getInstance(),
      );
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await repo.saveThresholdKeys({'$month|wallet:17|100'});
      final delivery = BudgetAlertDelivery(
        repository: repo,
        send: (_, _) async => fail('higher receipt covers lower thresholds'),
      );
      await delivery.evaluate([
        const BudgetSnapshot(
          id: 'wallet:17',
          label: '餐饮',
          spent: 85,
          limit: 100,
        ),
      ], now);
    },
  );
}
