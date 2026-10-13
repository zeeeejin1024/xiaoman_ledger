import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';
import 'package:xiaojia_ledger/core/notification_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy cleanup failure does not block reports and cleanup can retry',
    () async {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      var failCleanup = true;
      final pending = <int>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'cancel' &&
                failCleanup &&
                NotificationPolicy.legacyDailyIds.contains(
                  (call.arguments as Map)['id'],
                )) {
              throw PlatformException(code: 'cleanup_failed');
            }
            if (call.method == 'zonedSchedule') {
              pending.add((call.arguments as Map)['id']);
            }
            if (call.method == 'pendingNotificationRequests') {
              return pending
                  .map(
                    (id) => {'id': id, 'title': '', 'body': '', 'payload': ''},
                  )
                  .toList();
            }
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final coordinator = await NotificationCoordinator.shared();
      expect(await coordinator.reconcileAll(), isFalse);
      expect(
        pending,
        containsAll([
          NotificationPolicy.weeklyReportId,
          NotificationPolicy.monthlyReportId,
        ]),
      );
      failCleanup = false;
      expect(await coordinator.reconcileAll(), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'notification_rules_v2_migrated',
        ),
        isTrue,
      );
    },
  );
}
