import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/api_client.dart';
import '../data/api/record_api.dart';
import 'notification_models.dart';
import 'notification_policy.dart';
import 'notification_preferences.dart';
import 'notifications.dart';
import 'constants.dart';

/// Coordinates notification product rules without putting them in widgets.
class NotificationCoordinator {
  static NotificationCoordinator? _shared;

  final NotificationPreferencesRepository preferences;
  final DateTime Function() now;
  NotificationPreferences _settings;
  bool _busy = false;
  bool _reconcileQueued = false;

  NotificationCoordinator._(this.preferences, this._settings, this.now);

  static Future<NotificationCoordinator> shared() async {
    if (_shared != null) return _shared!;
    final repo = await NotificationPreferencesRepository.create();
    _shared = NotificationCoordinator._(repo, repo.load(), DateTime.now);
    return _shared!;
  }

  NotificationPreferences get settings => _settings;

  Future<bool> update(NotificationPreferences value) async {
    final permission = await NotificationService.isPermissionGranted();
    if (!_hasNewlyEnabledFeature(value) || permission) {
      _settings = value;
      await preferences.save(value);
      await reconcileAll();
      return true;
    }
    return false;
  }

  Future<bool> requestPermissionAndUpdate(NotificationPreferences value) async {
    if (_hasNewlyEnabledFeature(value) &&
        !await NotificationService.isPermissionGranted()) {
      if (!await NotificationService.requestPermission()) return false;
    }
    _settings = value;
    await preferences.save(value);
    await reconcileAll();
    return true;
  }

  Future<void> reconcileAll() async {
    if (_busy) {
      _reconcileQueued = true;
      return;
    }
    _busy = true;
    try {
      await NotificationService.init();
      if (!await NotificationService.isPermissionGranted()) {
        await NotificationService.cancelDailyWindow();
        await NotificationService.cancelWeekly();
        await NotificationService.cancelMonthly();
        await _reconcileDeals(disabled: true);
        return;
      }
      if (_settings.dailyEnabled) {
        final dates = NotificationPolicy.dailyOccurrences(
          now: now(),
          hour: _settings.dailyHour,
          minute: _settings.dailyMinute,
        );
        await NotificationService.scheduleDailyWindow(
          dates,
          hour: _settings.dailyHour,
          minute: _settings.dailyMinute,
        );
      } else {
        await NotificationService.cancelDailyWindow();
      }
      if (_settings.weeklyEnabled) {
        await NotificationService.scheduleWeekly(
          weekday: _settings.weeklyWeekday,
          hour: _settings.weeklyHour,
          minute: _settings.weeklyMinute,
        );
      } else {
        await NotificationService.cancelWeekly();
      }
      if (_settings.monthlyEnabled) {
        await NotificationService.scheduleMonthly(
          day: _settings.monthlyDay,
          hour: _settings.monthlyHour,
          minute: _settings.monthlyMinute,
        );
      } else {
        await NotificationService.cancelMonthly();
      }
      await _reconcileDeals();
      if (_settings.budgetEnabled) await evaluateBudgets();
    } catch (_) {
      // A single unavailable API or platform operation must not crash startup.
    } finally {
      _busy = false;
      if (_reconcileQueued) {
        _reconcileQueued = false;
        await reconcileAll();
      }
    }
  }

  Future<void> onRecordSaved({
    required DateTime date,
    required String type,
  }) async {
    if (date.year == now().year &&
        date.month == now().month &&
        date.day == now().day) {
      await NotificationService.cancelDailyWindow();
      if (_settings.dailyEnabled) {
        final today = DateTime(date.year, date.month, date.day);
        final future = NotificationPolicy.dailyOccurrences(
          now: now(),
          hour: _settings.dailyHour,
          minute: _settings.dailyMinute,
        ).where((scheduled) => !_sameDate(scheduled, today)).toList();
        await NotificationService.scheduleDailyWindow(
          future,
          hour: _settings.dailyHour,
          minute: _settings.dailyMinute,
        );
      }
    }
    if (type == 'expense' && _settings.budgetEnabled) await evaluateBudgets();
  }

  Future<void> evaluateBudgets() async {
    if (!await NotificationService.isPermissionGranted()) return;
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getStringList('active_wallets') ?? <String>[];
    if (active.isEmpty) return;
    final monthDate = now();
    final month =
        '${monthDate.year}-${monthDate.month.toString().padLeft(2, '0')}';
    final records = await RecordApi.getRecords(month: month);
    if (!records.isSuccess || records.data == null) return;
    final spent = <String, double>{};
    for (final record in records.data!) {
      if (!record.isIncome) {
        final id = '${record.categoryId}';
        spent[id] = (spent[id] ?? 0) + record.amount;
      }
    }
    final dedupe = preferences.thresholdKeys();
    for (final id in active) {
      final limit = prefs.getDouble('wallet_budget_$id') ?? 0;
      if (limit <= 0) continue;
      final current = spent[id] ?? 0;
      final previous = preferences.previousBudgetSpent(month, id);
      final crossed = NotificationPolicy.crossedBudgetThresholds(
        previousSpent: previous,
        currentSpent: current,
        limit: limit,
      );
      for (final threshold in crossed) {
        final key = NotificationPolicy.budgetDedupeKey(
          budgetId: id,
          month: monthDate,
          threshold: threshold,
        );
        if (dedupe.contains(key)) continue;
        try {
          await NotificationService.showBudgetAlert(
            budgetId: id,
            threshold: threshold,
          );
          dedupe.add(key);
        } catch (_) {}
      }
      await preferences.saveBudgetSpent(month, id, current);
    }
    await preferences.saveThresholdKeys(dedupe);
  }

  Future<void> _reconcileDeals({bool disabled = false}) async {
    final scheduled = preferences.scheduledDealIds().toSet();
    if (disabled || !_settings.dealsEnabled) {
      for (final id in scheduled) {
        await NotificationService.cancelDealId(id);
      }
      await preferences.saveScheduledDealIds(const <int>[]);
      return;
    }
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.tokenKey);
    if (token == null || token.isEmpty) return;
    List<DealReminder> deals;
    try {
      final response = await ApiClient().get('/deals');
      final raw = response.data['data'];
      if (raw is! List) return;
      deals = raw.map(_dealFromJson).whereType<DealReminder>().toList();
    } catch (_) {
      return;
    }
    final future = NotificationPolicy.futureDeals(deals, now());
    final currentIds = future.map((deal) => deal.id).toSet();
    for (final id in scheduled.difference(currentIds)) {
      await NotificationService.cancelDealId(id);
    }
    for (final deal in future) {
      try {
        await NotificationService.scheduleDeal(
          deal,
          hour: _settings.dealsHour,
          minute: _settings.dealsMinute,
        );
      } catch (_) {}
    }
    await preferences.saveScheduledDealIds(currentIds);
  }

  static DealReminder? _dealFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final date = DateTime.tryParse('${raw['remind_date'] ?? ''}');
    if (date == null) return null;
    final rawId = int.tryParse('${raw['id'] ?? ''}') ?? 0;
    final title = '${raw['title'] ?? ''}'.trim();
    if (title.isEmpty) return null;
    final id = rawId > 0 ? rawId : _stableSystemDealId(title, date);
    return DealReminder(
      id: id,
      title: title,
      description: '${raw['description'] ?? ''}',
      remindDate: date,
    );
  }

  static int _stableSystemDealId(String title, DateTime date) {
    var hash = date.year * 10000 + date.month * 100 + date.day;
    for (final code in title.codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }

  bool _hasNewlyEnabledFeature(NotificationPreferences value) =>
      (value.dailyEnabled && !_settings.dailyEnabled) ||
      (value.budgetEnabled && !_settings.budgetEnabled) ||
      (value.weeklyEnabled && !_settings.weeklyEnabled) ||
      (value.monthlyEnabled && !_settings.monthlyEnabled) ||
      (value.dealsEnabled && !_settings.dealsEnabled);

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
