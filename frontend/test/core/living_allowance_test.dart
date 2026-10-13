import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/living_allowance.dart';
import 'package:xiaojia_ledger/data/models/record.dart';

Record record(int id, String type, double amount, String date) => Record(
  id: id,
  type: type,
  amount: amount,
  categoryId: 1,
  categoryName: '测试',
  date: date,
);

void main() {
  test('payday defines a cross-month living allowance period', () {
    final period = LivingAllowancePeriod.forDate(DateTime(2026, 9, 17), 27);
    expect(period.start, DateTime(2026, 8, 27));
    expect(period.end, DateTime(2026, 9, 26));
  });

  test('summary includes opted-in income and expense only', () {
    final summary = LivingAllowanceSummary.calculate(
      settings: const LivingAllowanceSettings(baseAmount: 3000, payday: 1),
      records: [
        record(1, 'expense', 900, '2026-09-03'),
        record(2, 'income', 300, '2026-09-04'),
        record(3, 'income', 2000, '2026-09-05'),
        record(4, 'savings', 500, '2026-09-06'),
      ],
      includedIncomeIds: const {2},
      confirmedNoSpendDates: const {'2026-09-01', '2026-09-02'},
      now: DateTime(2026, 9, 5),
    );
    expect(summary.available, 3300);
    expect(summary.spent, 900);
    expect(summary.remaining, 2400);
    expect(summary.completeness, 1);
  });

  test('alert selects the highest newly crossed threshold', () {
    final alert = LivingAllowanceAlert.next(
      spentRatio: .92,
      alreadySent: const {75},
    );
    expect(alert?.threshold, 90);
    expect(
      LivingAllowanceAlert.next(spentRatio: .74, alreadySent: const {}),
      isNull,
    );
  });
}
