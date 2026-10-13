import 'package:xiaojia_ledger/data/models/record.dart';

class LivingAllowanceSettings {
  final double baseAmount;
  final int payday;
  final bool autoSaveRemainder;
  final bool setupComplete;

  const LivingAllowanceSettings({
    required this.baseAmount,
    required this.payday,
    this.autoSaveRemainder = true,
    this.setupComplete = false,
  });
}

class LivingAllowancePeriod {
  final DateTime start;
  final DateTime end;

  const LivingAllowancePeriod(this.start, this.end);

  factory LivingAllowancePeriod.forDate(DateTime value, int payday) {
    final day = payday.clamp(1, 28);
    final thisStart = DateTime(value.year, value.month, day);
    final start = value.isBefore(thisStart)
        ? DateTime(value.year, value.month - 1, day)
        : thisStart;
    return LivingAllowancePeriod(
      start,
      DateTime(
        start.year,
        start.month + 1,
        day,
      ).subtract(const Duration(days: 1)),
    );
  }

  LivingAllowancePeriod previous() {
    final previousEnd = start.subtract(const Duration(days: 1));
    return LivingAllowancePeriod.forDate(previousEnd, start.day);
  }

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);

  String get key =>
      '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
}

class LivingAllowanceSummary {
  final LivingAllowancePeriod period;
  final double available;
  final double spent;
  final double supplementalIncome;
  final double remaining;
  final double spentRatio;
  final double timeRatio;
  final double paceRatio;
  final double completeness;
  final int dailyAvailableDays;

  const LivingAllowanceSummary({
    required this.period,
    required this.available,
    required this.spent,
    required this.supplementalIncome,
    required this.remaining,
    required this.spentRatio,
    required this.timeRatio,
    required this.paceRatio,
    required this.completeness,
    required this.dailyAvailableDays,
  });

  factory LivingAllowanceSummary.calculate({
    required LivingAllowanceSettings settings,
    required Iterable<Record> records,
    required Set<int> includedIncomeIds,
    required Set<String> confirmedNoSpendDates,
    required DateTime now,
    LivingAllowancePeriod? period,
  }) {
    final target =
        period ?? LivingAllowancePeriod.forDate(now, settings.payday);
    double spent = 0;
    double supplemental = 0;
    final confirmedDates = <String>{...confirmedNoSpendDates};
    for (final record in records) {
      final date = DateTime.tryParse(record.date);
      if (date == null || !target.contains(date)) continue;
      confirmedDates.add(record.date);
      if (record.isExpense) spent += record.amount;
      if (record.isIncome && includedIncomeIds.contains(record.id)) {
        supplemental += record.amount;
      }
    }
    final available = settings.baseAmount + supplemental;
    final remaining = available - spent;
    final totalDays = target.end.difference(target.start).inDays + 1;
    final effectiveNow = now.isAfter(target.end) ? target.end : now;
    final elapsed = effectiveNow.isBefore(target.start)
        ? 0
        : effectiveNow.difference(target.start).inDays + 1;
    final confirmedInPeriod = confirmedDates.where((value) {
      final date = DateTime.tryParse(value);
      return date != null &&
          target.contains(date) &&
          !date.isAfter(effectiveNow);
    }).length;
    final spentRatio = available > 0 ? spent / available : 0.0;
    final timeRatio = totalDays > 0 ? elapsed / totalDays : 0.0;
    return LivingAllowanceSummary(
      period: target,
      available: available,
      spent: spent,
      supplementalIncome: supplemental,
      remaining: remaining,
      spentRatio: spentRatio,
      timeRatio: timeRatio,
      paceRatio: timeRatio > 0 ? spentRatio / timeRatio : 0,
      completeness: elapsed > 0 ? (confirmedInPeriod / elapsed).clamp(0, 1) : 0,
      dailyAvailableDays: (target.end.difference(effectiveNow).inDays + 1)
          .clamp(1, totalDays),
    );
  }

  double get dailyAvailable =>
      remaining > 0 ? remaining / dailyAvailableDays : 0;

  String get paceLabel {
    if (spentRatio >= 1) return '本期生活费已用完';
    if (paceRatio > 1.3) return '当前使用速度偏快';
    if (paceRatio > 1.1) return '当前使用速度略快';
    return '当前节奏正常';
  }
}

class LivingAllowanceAlert {
  final int threshold;
  const LivingAllowanceAlert(this.threshold);

  static LivingAllowanceAlert? next({
    required double spentRatio,
    required Set<int> alreadySent,
  }) {
    for (final threshold in const [100, 90, 75]) {
      if (spentRatio * 100 >= threshold) {
        if (alreadySent.any((sent) => sent >= threshold)) return null;
        return LivingAllowanceAlert(threshold);
      }
    }
    return null;
  }
}
