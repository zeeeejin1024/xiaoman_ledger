import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_models.dart';
import 'notification_policy.dart';

/// Platform adapter for local notifications.
/// Product rules live in NotificationCoordinator.
class NotificationService {
  static const androidSmallIcon = 'ic_notification';

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

  static Future<int> pendingCount() async {
    await init();
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> scheduleDailyWindow(
    List<DateTime> dates, {
    required int hour,
    required int minute,
  }) async {
    await init();
    await cancelDailyWindow();
    for (final date in dates) {
      await _schedule(
        NotificationPolicy.dailyIdForDate(date),
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
      '本周的省钱报告已生成，点击查看～',
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
      '上月的理财报告已生成，来看看你的表现吧～',
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

  static Future<void> cancelDailyWindow() async {
    await init();
    for (
      var id = NotificationPolicy.dailyBaseId;
      id <= NotificationPolicy.dailyBaseId + 89;
      id++
    ) {
      await _plugin.cancel(id);
    }
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
    await scheduleDailyWindow(
      [_nextDaily(hour, minute)],
      hour: hour,
      minute: minute,
    );
    return true;
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

  static tz.TZDateTime _nextDaily(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}
