import 'package:shared_preferences/shared_preferences.dart';
import 'notification_models.dart';

/// Owns all notification-related local settings and migration.
class NotificationPreferencesRepository {
  static const _prefix = 'notification.';
  static const _schemaKey = '${_prefix}schema';
  static const _dedupeKey = '${_prefix}budget_dedupe';

  final SharedPreferences _prefs;

  NotificationPreferencesRepository(this._prefs);

  bool hasRecordedOn(DateTime date) =>
      _prefs.getString('${_prefix}last_recorded_date') == _date(date);

  Future<void> markRecordedOn(DateTime date) async {
    if (!await _prefs.setString('${_prefix}last_recorded_date', _date(date))) {
      throw StateError('Unable to persist recorded date');
    }
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';

  static Future<NotificationPreferencesRepository> create() async {
    return NotificationPreferencesRepository(
      await SharedPreferences.getInstance(),
    );
  }

  NotificationPreferences load() {
    final migratedDaily = _prefs.containsKey('${_prefix}daily_enabled')
        ? _prefs.getBool('${_prefix}daily_enabled')
        : _prefs.getBool('reminder_enabled');
    final oldTime = _prefs.getString('reminder_time');
    final parsedOldTime = _parseTime(oldTime, const _Time(21, 0));
    final values = NotificationPreferences(
      dailyEnabled: migratedDaily ?? false,
      dailyHour: _validHour(
        _prefs.getInt('${_prefix}daily_hour') ?? parsedOldTime.hour,
      ),
      dailyMinute: _validMinute(
        _prefs.getInt('${_prefix}daily_minute') ?? parsedOldTime.minute,
      ),
      budgetEnabled: _prefs.getBool('${_prefix}budget_enabled') ?? false,
      livingEnabled: _prefs.getBool('${_prefix}living_enabled') ?? true,
      weeklyEnabled: _prefs.getBool('${_prefix}weekly_enabled') ?? true,
      weeklyWeekday: _validWeekday(
        _prefs.getInt('${_prefix}weekly_weekday') ?? DateTime.monday,
      ),
      weeklyHour: _validHour(_prefs.getInt('${_prefix}weekly_hour') ?? 9),
      weeklyMinute: _validMinute(_prefs.getInt('${_prefix}weekly_minute') ?? 0),
      monthlyEnabled: _prefs.getBool('${_prefix}monthly_enabled') ?? true,
      monthlyDay: _validDay(_prefs.getInt('${_prefix}monthly_day') ?? 1),
      monthlyHour: _validHour(_prefs.getInt('${_prefix}monthly_hour') ?? 9),
      monthlyMinute: _validMinute(
        _prefs.getInt('${_prefix}monthly_minute') ?? 0,
      ),
      dealsEnabled: _prefs.getBool('${_prefix}deals_enabled') ?? false,
      dealsHour: _validHour(_prefs.getInt('${_prefix}deals_hour') ?? 9),
      dealsMinute: _validMinute(_prefs.getInt('${_prefix}deals_minute') ?? 0),
    );
    return values;
  }

  Future<void> save(NotificationPreferences value) async {
    final normalized = value.copyWith(
      dailyHour: _validHour(value.dailyHour),
      dailyMinute: _validMinute(value.dailyMinute),
      weeklyWeekday: _validWeekday(value.weeklyWeekday),
      weeklyHour: _validHour(value.weeklyHour),
      weeklyMinute: _validMinute(value.weeklyMinute),
      monthlyDay: _validDay(value.monthlyDay),
      monthlyHour: _validHour(value.monthlyHour),
      monthlyMinute: _validMinute(value.monthlyMinute),
      dealsHour: _validHour(value.dealsHour),
      dealsMinute: _validMinute(value.dealsMinute),
    );
    final saved = await Future.wait([
      _prefs.setInt(_schemaKey, 1),
      _prefs.setBool('${_prefix}daily_enabled', normalized.dailyEnabled),
      _prefs.setInt('${_prefix}daily_hour', normalized.dailyHour),
      _prefs.setInt('${_prefix}daily_minute', normalized.dailyMinute),
      _prefs.setBool('${_prefix}budget_enabled', normalized.budgetEnabled),
      _prefs.setBool('${_prefix}living_enabled', normalized.livingEnabled),
      _prefs.setBool('${_prefix}weekly_enabled', normalized.weeklyEnabled),
      _prefs.setInt('${_prefix}weekly_weekday', normalized.weeklyWeekday),
      _prefs.setInt('${_prefix}weekly_hour', normalized.weeklyHour),
      _prefs.setInt('${_prefix}weekly_minute', normalized.weeklyMinute),
      _prefs.setBool('${_prefix}monthly_enabled', normalized.monthlyEnabled),
      _prefs.setInt('${_prefix}monthly_day', normalized.monthlyDay),
      _prefs.setInt('${_prefix}monthly_hour', normalized.monthlyHour),
      _prefs.setInt('${_prefix}monthly_minute', normalized.monthlyMinute),
      _prefs.setBool('${_prefix}deals_enabled', normalized.dealsEnabled),
      _prefs.setInt('${_prefix}deals_hour', normalized.dealsHour),
      _prefs.setInt('${_prefix}deals_minute', normalized.dealsMinute),
    ]);
    if (saved.any((ok) => !ok)) {
      throw StateError('Unable to persist notification preferences');
    }
    // Preserve compatibility for the existing settings page until it is fully migrated.
    await _prefs.setBool('reminder_enabled', normalized.dailyEnabled);
    await _prefs.setString(
      'reminder_time',
      _formatTime(normalized.dailyHour, normalized.dailyMinute),
    );
  }

  Set<String> thresholdKeys() =>
      (_prefs.getStringList(_dedupeKey) ?? <String>[]).toSet();

  Future<void> saveThresholdKeys(Set<String> values) async {
    final now = DateTime.now();
    final currentPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}|';
    final recent = values.where((key) => key.startsWith(currentPrefix)).toList()
      ..sort();
    await _prefs.setStringList(_dedupeKey, recent);
  }

  List<int> scheduledDealIds() =>
      (_prefs.getStringList('${_prefix}deal_ids') ?? <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toList();

  Future<void> saveScheduledDealIds(Iterable<int> ids) async {
    await _prefs.setStringList(
      '${_prefix}deal_ids',
      ids.map((id) => '$id').toList(),
    );
  }

  double previousBudgetSpent(String month, String budgetId) =>
      _prefs.getDouble('${_prefix}spent.$month.$budgetId') ?? 0;

  Future<void> saveBudgetSpent(String month, String budgetId, double spent) =>
      _prefs.setDouble('${_prefix}spent.$month.$budgetId', spent);

  static String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static _Time _parseTime(String? value, _Time fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return fallback;
    }
    return _Time(hour, minute);
  }

  static int _validHour(int value) => value.clamp(0, 23);
  static int _validMinute(int value) => value.clamp(0, 59);
  static int _validWeekday(int value) =>
      value.clamp(DateTime.monday, DateTime.sunday);
  static int _validDay(int value) => value.clamp(1, 28);
}

class _Time {
  final int hour;
  final int minute;
  const _Time(this.hour, this.minute);
}
