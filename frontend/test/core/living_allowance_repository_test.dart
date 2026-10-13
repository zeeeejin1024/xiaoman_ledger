import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/living_allowance_repository.dart';
import 'package:xiaojia_ledger/core/living_allowance.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'living_expense': 2500.0,
      'pay_day': 27,
    }),
  );

  test('loads compatible legacy living allowance settings', () async {
    final repo = LivingAllowanceRepository(
      await SharedPreferences.getInstance(),
    );
    final value = repo.loadSettings();
    expect(value.baseAmount, 2500);
    expect(value.payday, 27);
  });

  test('income and no-spend markers are deduplicated', () async {
    final repo = LivingAllowanceRepository(
      await SharedPreferences.getInstance(),
    );
    await repo.includeIncomeRecord(8);
    await repo.includeIncomeRecord(8);
    await repo.confirmNoSpendDate(DateTime(2026, 9, 17));
    await repo.confirmNoSpendDate(DateTime(2026, 9, 17));
    expect(repo.includedIncomeIds(), {8});
    expect(repo.confirmedNoSpendDates(), {'2026-09-17'});
  });

  test(
    'first setup starts rollover from the current period, not retroactively',
    () async {
      final repo = LivingAllowanceRepository(
        await SharedPreferences.getInstance(),
      );
      await repo.saveSettings(
        const LivingAllowanceSettings(
          baseAmount: 3000,
          payday: 27,
          setupComplete: true,
        ),
      );
      expect(repo.startedPeriodKey, isNotNull);
    },
  );
}
