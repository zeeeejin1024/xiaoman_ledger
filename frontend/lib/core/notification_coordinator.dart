import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api/api_client.dart';
import '../data/api/wallet_api.dart';
import 'notification_models.dart';
import 'notification_policy.dart';
import 'notification_preferences.dart';
import 'notifications.dart';
import 'constants.dart';
import 'notifications/notification_migrator.dart';
import 'notifications/notification_audit.dart';
import 'notifications/platform_scheduler.dart';
import 'notifications/schedule_plan.dart';
import 'notifications/notification_rule.dart';
import 'notifications/threshold_delivery.dart';

/// Coordinates notification product rules without putting them in widgets.
class NotificationCoordinator {
  static NotificationCoordinator? _shared;
  static Future<NotificationCoordinator>? _creating;

  final NotificationPreferencesRepository preferences;
  final DateTime Function() now;
  NotificationPreferences _settings;
  Future<void> _reconcileTail = Future<void>.value();
  final NotificationAuditStore dailyAudit = NotificationAuditStore();
  late final BudgetAlertDelivery _budgetDelivery = BudgetAlertDelivery(
    repository: preferences,
    send: (id, threshold) =>
        NotificationService.showBudgetAlert(budgetId: id, threshold: threshold),
  );

  NotificationCoordinator._(this.preferences, this._settings, this.now);

  static Future<NotificationCoordinator> shared() =>
      _creating ??= _createShared();

  static Future<NotificationCoordinator> _createShared() async {
    try {
      final repo = await NotificationPreferencesRepository.create();
      _shared = NotificationCoordinator._(repo, repo.load(), DateTime.now);
      await _shared!._migrateLegacyRules();
      return _shared!;
    } catch (_) {
      _creating = null;
      rethrow;
    }
  }

  Future<bool> _migrateLegacyRules() async {
    final migrator = NotificationMigrator(
      // The repository has already loaded the same SharedPreferences instance.
      await SharedPreferences.getInstance(),
      _CoordinatorMigrationScheduler(),
    );
    try {
      return await migrator.run();
    } catch (error) {
      // Keep the migration marker absent so a later reconciliation retries.
      debugPrint('Legacy notification migration pending: ${error.runtimeType}');
      return false;
    }
  }

  NotificationPreferences get settings => _settings;

  Future<bool> update(NotificationPreferences value) async {
    final permission = await NotificationService.isPermissionGranted();
    if (!_hasNewlyEnabledFeature(value) || permission) {
      await preferences.save(value);
      _settings = preferences.load();
      return await reconcileAll();
    }
    return false;
  }

  Future<bool> requestPermissionAndUpdate(NotificationPreferences value) async {
    if (_hasNewlyEnabledFeature(value) &&
        !await NotificationService.isPermissionGranted()) {
      if (!await NotificationService.requestPermission()) return false;
    }
    await preferences.save(value);
    _settings = preferences.load();
    return await reconcileAll();
  }

  Future<bool> reconcileAll() {
    final run = _reconcileTail.then((_) => _reconcileOnce());
    _reconcileTail = run.then<void>((_) {});
    return run;
  }

  Future<bool> _reconcileOnce() async {
    try {
      await NotificationService.init();
      final permission = await NotificationService.isPermissionGranted();
      var success = await _migrateLegacyRules();
      Future<void> attempt(Future<void> Function() operation) async {
        try {
          await operation();
        } catch (error) {
          success = false;
          debugPrint('Notification rule failed: ${error.runtimeType}');
        }
      }

      if (!permission) {
        await attempt(NotificationService.cancelDailyWindow);
        if (!await _auditDaily(permission)) success = false;
        await attempt(NotificationService.cancelWeekly);
        await attempt(NotificationService.cancelMonthly);
        await attempt(() => _reconcileDeals(disabled: true));
      } else {
        if (!await _auditDaily(permission)) success = false;
        await attempt(() async {
          if (_settings.weeklyEnabled) {
            await NotificationService.scheduleWeekly(
              weekday: _settings.weeklyWeekday,
              hour: _settings.weeklyHour,
              minute: _settings.weeklyMinute,
            );
          } else {
            await NotificationService.cancelWeekly();
          }
        });
        await attempt(() async {
          if (_settings.monthlyEnabled) {
            await NotificationService.scheduleMonthly(
              day: _settings.monthlyDay,
              hour: _settings.monthlyHour,
              minute: _settings.monthlyMinute,
            );
          } else {
            await NotificationService.cancelMonthly();
          }
        });
        await attempt(() => _reconcileDeals());
        if (_settings.budgetEnabled) await attempt(evaluateBudgets);
      }
      return success;
    } catch (error) {
      debugPrint('Notification reconciliation failed: $error');
      return false;
    }
  }

  Future<bool> _auditDaily(bool permission) async {
    final rule = NotificationRule(
      id: 'daily',
      enabled: _settings.dailyEnabled,
      time: TimeOfDay(hour: _settings.dailyHour, minute: _settings.dailyMinute),
      kind: NotificationRuleKind.daily,
    );
    final plan = const NotificationPlanner().plan(
      rule: rule,
      now: now(),
      notificationsAllowed: permission,
      // The app intentionally uses the battery-friendly inexact Android mode.
      exactAlarmAllowed: false,
      skipToday: preferences.hasRecordedOn(now()),
    );
    final audit = await PlatformScheduler(
      dailyAudit,
    ).apply(rule: rule, plan: plan);
    return audit.state == AuditState.scheduled ||
        audit.state == AuditState.degraded ||
        audit.state == AuditState.disabled ||
        audit.state == AuditState.blocked;
  }

  Future<void> onRecordSaved({
    required DateTime date,
    required String type,
  }) async {
    if (date.year == now().year &&
        date.month == now().month &&
        date.day == now().day) {
      await preferences.markRecordedOn(date);
    }
    // Share the serialized scheduling path with foreground refresh/settings.
    await reconcileAll();
  }

  Future<void> evaluateBudgets() async {
    if (!_settings.budgetEnabled ||
        !await NotificationService.isPermissionGranted()) {
      return;
    }
    final monthDate = now();
    final remote = await WalletApi.getWallets();
    // Missing current data is not an empty wallet and must not revive legacy
    // category budgets. Leave receipts unchanged and retry on the next refresh.
    if (remote == null || !_settings.budgetEnabled) return;
    final snapshots = remote
        .map(
          (wallet) => BudgetSnapshot(
            id: 'wallet:${wallet.id}',
            label: wallet.name,
            spent: wallet.spent,
            limit: wallet.amount,
          ),
        )
        .toList();
    await _budgetDelivery.evaluate(snapshots, monthDate);
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
    final pendingDeals = future
        .where(
          (deal) => DateTime(
            deal.remindDate.year,
            deal.remindDate.month,
            deal.remindDate.day,
            _settings.dealsHour,
            _settings.dealsMinute,
          ).isAfter(now()),
        )
        .toList();
    final currentIds = pendingDeals.map((deal) => deal.id).toSet();
    for (final id in scheduled.difference(currentIds)) {
      await NotificationService.cancelDealId(id);
    }
    final registered = <int>{};
    final pendingIds = await NotificationService.pendingRequestIds();
    for (final deal in pendingDeals) {
      try {
        await NotificationService.scheduleDeal(
          deal,
          hour: _settings.dealsHour,
          minute: _settings.dealsMinute,
        );
        registered.add(deal.id);
      } catch (_) {
        // Retain older registrations so disabling can still cancel them.
        if (pendingIds.contains(NotificationPolicy.dealId(deal.id))) {
          registered.add(deal.id);
        }
      }
    }
    await preferences.saveScheduledDealIds(registered);
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
      (value.livingEnabled && !_settings.livingEnabled) ||
      (value.weeklyEnabled && !_settings.weeklyEnabled) ||
      (value.monthlyEnabled && !_settings.monthlyEnabled) ||
      (value.dealsEnabled && !_settings.dealsEnabled);
}

class _CoordinatorMigrationScheduler implements NotificationMigrationScheduler {
  @override
  Future<AuditState> schedule(NotificationMigrationRule rule) async {
    try {
      await NotificationService.scheduleDailyReminder(
        hour: rule.rule.time.hour,
        minute: rule.rule.time.minute,
      );
      return AuditState.scheduled;
    } catch (_) {
      return AuditState.failed;
    }
  }

  @override
  Future<void> cancelLegacy() => NotificationService.cancelLegacyDailyIds();
}
