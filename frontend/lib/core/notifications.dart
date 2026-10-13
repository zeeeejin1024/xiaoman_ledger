import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_models.dart';
import 'notification_policy.dart';
import 'notification_preferences.dart';

/// Platform adapter for local notifications.
/// Product rules live in NotificationCoordinator.
class NotificationService {
  static const androidSmallIcon = 'ic_notification';
  static const _legacyDailyCleanupKey =
      'notification.legacy_daily_window_cleaned_v581';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static void Function(int id)? onNotificationTapped;
  static void Function(NotificationPayload payload)? onNotificationPayload;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      const android = AndroidInitializationSettings(androidSmallIcon);
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      final initialized = await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          final payload = NotificationPayload.decode(response.payload);
          onNotificationPayload?.call(payload);
          if (response.id != null) onNotificationTapped?.call(response.id!);
        },
      );
      _initialized = initialized ?? true;
      if (_initialized) {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          onNotificationPayload?.call(
            NotificationPayload.decode(launch?.notificationResponse?.payload),
          );
        }
      }
    } catch (error) {
      debugPrint('NotificationService init failed: ${error.runtimeType}');
    }
  }

  static Future<bool> isPermissionGranted() async {
    await init();
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.areNotificationsEnabled() ?? false;
      }
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final settings = await ios?.checkPermissions();
        return settings?.isEnabled ?? true;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    try {
      if (Platform.isAndroid) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }
      if (Platform.isIOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openSystemNotificationSettings() async {
    try {
      return await permissions.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  static Future<NotificationQueueState> pendingState() async {
    await init();
    try {
      return NotificationQueueState.ready(
        (await _plugin.pendingNotificationRequests()).length,
      );
    } catch (_) {
      return NotificationQueueState.unavailable;
    }
  }

  static Future<int> pendingCount() async {
    final state = await pendingState();
    if (!state.isAvailable) {
      throw StateError('Unable to query pending notifications');
    }
    return state.count!;
  }

  static Future<Set<int>> pendingRequestIds() async {
    await init();
    final requests = await _plugin.pendingNotificationRequests();
    return requests.map((request) => request.id).toSet();
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    bool skipToday = false,
  }) async {
    await init();
    final now = DateTime.now();
    final preferences = await NotificationPreferencesRepository.create();
    final dates = NotificationPolicy.dailyOccurrences(
      now: now,
      hour: hour,
      minute: minute,
      days: NotificationPolicy.dailyWindowDays,
      skipToday: skipToday || preferences.hasRecordedOn(now),
    );
    await scheduleDailyWindow(dates, hour: hour, minute: minute);
  }

  static Future<void> scheduleDailyWindow(
    List<DateTime> dates, {
    required int hour,
    required int minute,
  }) async {
    if (dates.length > NotificationPolicy.dailyWindowDays) {
      throw ArgumentError('Daily window exceeds the supported limit');
    }
    await init();
    for (final (index, date) in dates.indexed) {
      await _schedule(
        NotificationPolicy.dailyReminderId + index,
        '记账提醒',
        '今天还没有记账哦，记一笔就安心啦～',
        date,
        channelId: 'daily_reminder',
        channelName: '每日记账提醒',
        payload: const NotificationPayload(
          type: 'daily',
          route: 'home',
          action: 'add_record',
        ).encode(),
      );
    }
    final pending = await pendingRequestIds();
    if (!pending.containsAll(
      List.generate(
        dates.length,
        (index) => NotificationPolicy.dailyReminderId + index,
      ),
    )) {
      throw StateError('Daily reminder window was not registered');
    }
    // Replace stable IDs in place. Do not erase working reminders before the
    // platform has accepted the replacement window.
    for (final id in NotificationPolicy.dailyWindowIds.skip(dates.length)) {
      await _plugin.cancel(id);
    }
    await cancelLegacyDailyIds();
  }

  static Future<void> scheduleWeekly({
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    await init();
    await _plugin.cancel(NotificationPolicy.weeklyReportId);
    await _schedule(
      NotificationPolicy.weeklyReportId,
      '省钱周报',
      '到复盘本周收支的时间了，打开查看省钱周报。',
      NotificationPolicy.nextWeeklyOccurrence(
        now: DateTime.now(),
        weekday: weekday,
        hour: hour,
        minute: minute,
      ),
      channelId: 'weekly_report',
      channelName: '周报提醒',
      match: DateTimeComponents.dayOfWeekAndTime,
      payload: const NotificationPayload(
        type: 'weekly',
        route: 'weekly_report',
      ).encode(),
    );
    await _confirmPending(NotificationPolicy.weeklyReportId);
  }

  static Future<void> scheduleMonthly({
    required int day,
    required int hour,
    required int minute,
  }) async {
    await init();
    await _plugin.cancel(NotificationPolicy.monthlyReportId);
    await _schedule(
      NotificationPolicy.monthlyReportId,
      '月度报告',
      '回顾上月收支，打开查看月度报告。',
      NotificationPolicy.nextMonthlyOccurrence(
        now: DateTime.now(),
        day: day,
        hour: hour,
        minute: minute,
      ),
      channelId: 'monthly_report',
      channelName: '月报提醒',
      match: DateTimeComponents.dayOfMonthAndTime,
      payload: const NotificationPayload(
        type: 'monthly',
        route: 'monthly_report',
      ).encode(),
    );
    await _confirmPending(NotificationPolicy.monthlyReportId);
  }

  static Future<void> scheduleDeal(
    DealReminder deal, {
    required int hour,
    required int minute,
  }) async {
    await init();
    final date = DateTime(
      deal.remindDate.year,
      deal.remindDate.month,
      deal.remindDate.day,
      hour,
      minute,
    );
    if (!date.isAfter(DateTime.now())) {
      await cancelDealId(deal.id);
      return;
    }
    await _schedule(
      NotificationPolicy.dealId(deal.id),
      '优惠提醒',
      '有一条优惠提醒，打开小满记账查看详情～',
      date,
      channelId: 'deal_reminder',
      channelName: '优惠提醒',
      payload: NotificationPayload(
        type: 'deal',
        route: 'profile',
        entityId: deal.id,
      ).encode(),
    );
    await _confirmPending(NotificationPolicy.dealId(deal.id));
  }

  static Future<void> showBudgetAlert({
    required String budgetId,
    required BudgetThreshold threshold,
  }) async {
    await init();
    final value = threshold == BudgetThreshold.eightyPercent ? '80%' : '100%';
    await _plugin.show(
      NotificationPolicy.budgetId('$budgetId:$value'),
      '预算提醒',
      '有一项预算已达到 $value，打开小满记账查看详情～',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alert',
          '预算提醒',
          channelDescription: '预算阈值提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: const NotificationPayload(
        type: 'budget',
        route: 'wallet',
      ).encode(),
    );
  }

  static Future<void> showLivingAllowanceAlert({
    required int threshold,
    required double remaining,
  }) async {
    await init();
    final body = threshold >= 100
        ? '本期生活费已经用完，建议检查是否有漏记或调整接下来的安排。'
        : '本期生活费已使用 $threshold%，还剩 ¥${remaining.toStringAsFixed(2)}。';
    await _plugin.show(
      NotificationPolicy.budgetId('living:$threshold'),
      '生活费提醒',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'living_allowance_alert',
          '生活费提醒',
          channelDescription: '生活费使用进度和阈值提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: const NotificationPayload(
        type: 'budget',
        route: 'home',
      ).encode(),
    );
  }

  static Future<void> cancelDailyWindow() async {
    await init();
    for (final id in NotificationPolicy.dailyWindowIds) {
      await _plugin.cancel(id);
    }
    await cancelLegacyDailyIds();
  }

  static Future<void> cancelLegacyDailyIds() async {
    await init();
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_legacyDailyCleanupKey) == true) return;
    for (final id in NotificationPolicy.legacyDailyIds) {
      await _plugin.cancel(id);
    }
    await preferences.setBool(_legacyDailyCleanupKey, true);
  }

  static Future<void> cancelWeekly() async {
    await init();
    await _plugin.cancel(NotificationPolicy.weeklyReportId);
  }

  static Future<void> cancelMonthly() async {
    await init();
    await _plugin.cancel(NotificationPolicy.monthlyReportId);
  }

  static Future<void> cancelAllDeals(Iterable<DealReminder> deals) async {
    await init();
    for (final deal in deals) {
      await _plugin.cancel(NotificationPolicy.dealId(deal.id));
    }
  }

  static Future<void> cancelDealId(int dealId) async {
    await init();
    await _plugin.cancel(NotificationPolicy.dealId(dealId));
  }

  static Future<void> scheduleWeeklyReport() =>
      scheduleWeekly(weekday: DateTime.monday, hour: 9, minute: 0);
  static Future<void> scheduleMonthlyReport() =>
      scheduleMonthly(day: 1, hour: 9, minute: 0);

  static Future<bool> scheduleReminder(int hour, int minute) async {
    try {
      await scheduleDailyReminder(hour: hour, minute: minute);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancelReminder() => cancelDailyWindow();

  static Future<void> testNotification() async {
    await init();
    await _plugin.show(
      NotificationPolicy.testImmediateId,
      '测试通知',
      '小满记账通知功能正常！',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test',
          '测试通知',
          channelDescription: '测试通知',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: const NotificationPayload(type: 'test', route: 'home').encode(),
    );
  }

  static Future<bool> testScheduledNotification() async {
    await init();
    if (!await requestPermission()) return false;
    final at = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 15));
    try {
      await _schedule(
        NotificationPolicy.testScheduledId,
        '定时通知测试',
        '如果你看到这条通知，说明定时提醒功能正常。',
        at,
        channelId: 'test',
        channelName: '测试通知',
        payload: const NotificationPayload(
          type: 'test',
          route: 'home',
        ).encode(),
      );
      await _confirmPending(NotificationPolicy.testScheduledId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime date, {
    required String channelId,
    required String channelName,
    required String payload,
    DateTimeComponents? match,
  }) async {
    final scheduled = date is tz.TZDateTime
        ? date
        : tz.TZDateTime.from(date, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local)) && match == null) {
      return;
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: match,
      payload: payload,
    );
  }

  static Future<void> _confirmPending(int id) async {
    if (!(await pendingRequestIds()).contains(id)) {
      throw StateError('Notification $id was not registered');
    }
  }
}
