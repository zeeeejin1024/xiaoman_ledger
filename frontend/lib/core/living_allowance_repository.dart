import 'package:shared_preferences/shared_preferences.dart';
import 'living_allowance.dart';

class LivingAllowanceRepository {
  final SharedPreferences preferences;
  LivingAllowanceRepository(this.preferences);

  LivingAllowanceSettings loadSettings() => LivingAllowanceSettings(
    baseAmount:
        preferences.getDouble('living_allowance_base') ??
        preferences.getDouble('living_expense') ??
        0,
    payday:
        preferences.getInt('living_allowance_payday') ??
        preferences.getInt('pay_day') ??
        1,
    autoSaveRemainder:
        preferences.getBool('living_allowance_auto_save') ?? true,
    setupComplete:
        preferences.getBool('living_allowance_setup_complete') ?? false,
  );

  Future<void> saveSettings(LivingAllowanceSettings value) async {
    await preferences.setDouble('living_allowance_base', value.baseAmount);
    await preferences.setDouble('living_expense', value.baseAmount);
    await preferences.setInt(
      'living_allowance_payday',
      value.payday.clamp(1, 28),
    );
    await preferences.setInt('pay_day', value.payday.clamp(1, 28));
    await preferences.setBool(
      'living_allowance_auto_save',
      value.autoSaveRemainder,
    );
    await preferences.setBool('living_allowance_setup_complete', true);
    if (startedPeriodKey == null) {
      final period = LivingAllowancePeriod.forDate(
        DateTime.now(),
        value.payday,
      );
      await preferences.setString(
        'living_allowance_started_period',
        period.key,
      );
    }
  }

  String? get startedPeriodKey =>
      preferences.getString('living_allowance_started_period');

  Set<int> includedIncomeIds() =>
      (preferences.getStringList('living_allowance_income_ids') ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> includeIncomeRecord(int id) async {
    final values = includedIncomeIds()..add(id);
    await preferences.setStringList(
      'living_allowance_income_ids',
      values.map((e) => '$e').toList(),
    );
  }

  Set<String> confirmedNoSpendDates() =>
      (preferences.getStringList('living_allowance_no_spend_dates') ?? const [])
          .toSet();

  Future<void> confirmNoSpendDate(DateTime date) async {
    final values = confirmedNoSpendDates()..add(_date(date));
    await preferences.setStringList(
      'living_allowance_no_spend_dates',
      values.toList()..sort(),
    );
  }

  Set<int> sentThresholds(String periodKey) =>
      (preferences.getStringList('living_allowance_alerts_$periodKey') ??
              const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> markThresholdSent(String periodKey, int threshold) async {
    final values = sentThresholds(periodKey)..add(threshold);
    await preferences.setStringList(
      'living_allowance_alerts_$periodKey',
      values.map((e) => '$e').toList(),
    );
  }

  bool wasRolledOver(String periodKey) =>
      preferences.getBool('living_allowance_rolled_$periodKey') ?? false;

  Set<int> notifiedThresholds(String periodKey) =>
      (preferences.getStringList('living_allowance_notified_$periodKey') ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> markThresholdNotified(String periodKey, int threshold) async {
    final values = notifiedThresholds(periodKey)..add(threshold);
    if (!await preferences.setStringList(
      'living_allowance_notified_$periodKey',
      values.map((e) => '$e').toList(),
    )) {
      throw StateError('Unable to persist notification receipt');
    }
  }

  Future<void> markRolledOver(String periodKey) =>
      preferences.setBool('living_allowance_rolled_$periodKey', true);

  int? get savingsGoalId =>
      preferences.getInt('living_allowance_savings_goal_id');
  Future<void> setSavingsGoalId(int id) =>
      preferences.setInt('living_allowance_savings_goal_id', id);

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
