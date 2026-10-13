import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/notification_policy.dart';
import 'package:xiaojia_ledger/core/notification_preferences.dart';
import 'package:xiaojia_ledger/core/notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final pending = <int>{};
  final scheduled = <Map<dynamic, dynamic>>[];
  var register = true;
  var failSchedule = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    pending.clear();
    scheduled.clear();
    register = true;
    failSchedule = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'zonedSchedule') {
            if (failSchedule) throw PlatformException(code: 'schedule_failed');
            final args = call.arguments as Map;
            scheduled.add(args);
            if (register) pending.add(args['id'] as int);
          }
          if (call.method == 'cancel') {
            pending.remove((call.arguments as Map)['id']);
          }
          if (call.method == 'pendingNotificationRequests') {
            return pending
                .map((id) => {'id': id, 'title': '', 'body': '', 'payload': ''})
                .toList();
          }
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'reconciliation after recording starts tomorrow with 30 one-shot requests',
    () async {
      final now = DateTime.now();
      await (await NotificationPreferencesRepository.create()).markRecordedOn(
        now,
      );
      await NotificationService.scheduleDailyReminder(hour: 23, minute: 59);
      expect(scheduled, hasLength(30));
      expect(pending, NotificationPolicy.dailyWindowIds.toSet());
      final tomorrow = DateTime(now.year, now.month, now.day + 1, 23, 59);
      final first = DateTime.parse(
        scheduled.first['scheduledDateTime'] as String,
      );
      expect(
        [first.year, first.month, first.day, first.hour, first.minute],
        [tomorrow.year, tomorrow.month, tomorrow.day, 23, 59],
      );
      expect(
        scheduled.every((item) => item['matchDateTimeComponents'] == null),
        isTrue,
      );
      await NotificationService.scheduleDailyReminder(hour: 23, minute: 59);
      expect(pending.length, 30);
      await NotificationService.cancelDailyWindow();
      expect(pending, isEmpty);
    },
  );

  test(
    'invalid oversized window must preserve already scheduled requests',
    () async {
      await NotificationService.scheduleDailyReminder(hour: 21, minute: 0);
      final previous = Set<int>.from(pending);
      await expectLater(
        NotificationService.scheduleDailyWindow(
          List.generate(
            31,
            (index) => DateTime.now().add(Duration(days: index + 1)),
          ),
          hour: 21,
          minute: 0,
        ),
        throwsArgumentError,
      );
      expect(pending, previous);
    },
  );

  test(
    'scheduled test cannot claim success if pending registration is absent',
    () async {
      register = false;
      expect(await NotificationService.testScheduledNotification(), isFalse);
      expect(scheduled.single['id'], NotificationPolicy.testScheduledId);
    },
  );

  test('report scheduling propagates queue registration failure', () async {
    register = false;
    await expectLater(
      NotificationService.scheduleWeekly(weekday: 1, hour: 9, minute: 0),
      throwsStateError,
    );
    await expectLater(
      NotificationService.scheduleMonthly(day: 1, hour: 9, minute: 0),
      throwsStateError,
    );
  });

  test(
    'failed replacement preserves legacy reminders until verification succeeds',
    () async {
      pending.addAll(NotificationPolicy.legacyDailyIds);
      failSchedule = true;
      await expectLater(
        NotificationService.scheduleDailyReminder(hour: 21, minute: 0),
        throwsA(isA<PlatformException>()),
      );
      expect(pending, containsAll(NotificationPolicy.legacyDailyIds));
      failSchedule = false;
      await NotificationService.scheduleDailyReminder(hour: 21, minute: 0);
      expect(pending, NotificationPolicy.dailyWindowIds.toSet());
    },
  );
}
