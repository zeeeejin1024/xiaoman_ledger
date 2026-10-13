import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/modules/notifications/notification_diagnostics_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final pending = <int>{};
  Completer<void>? reading;
  var failSchedule = false;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    pending.clear();
    reading = null;
    failSchedule = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'zonedSchedule') {
            if (failSchedule) throw PlatformException(code: 'schedule_failed');
            pending.add((call.arguments as Map)['id'] as int);
          }
          if (call.method == 'pendingNotificationRequests') {
            await reading?.future;
            return pending
                .map((id) => {'id': id, 'title': '', 'body': '', 'payload': ''})
                .toList();
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'pending permission is shown as checking, not denied',
    (tester) async {
      reading = Completer<void>();
      await tester.pumpWidget(
        const MaterialApp(home: NotificationDiagnosticsPage()),
      );
      await tester.pump();
      expect(find.text('读取中'), findsWidgets);
      expect(find.text('未允许'), findsNothing);
      reading!.complete();
      await tester.pumpAndSettle();
      expect(find.text('已允许'), findsOneWidget);
      expect(find.text('0 条'), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'scheduled test can recover from error and does not promise exact delivery',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: NotificationDiagnosticsPage()),
      );
      await tester.pumpAndSettle();
      failSchedule = true;
      await tester.tap(find.text('安排定时测试'));
      await tester.pumpAndSettle();
      expect(find.text('测试失败，请检查通知权限和后台设置'), findsOneWidget);
      failSchedule = false;
      await tester.tap(find.text('安排定时测试'));
      await tester.pumpAndSettle();
      expect(
        find.text('系统队列已确认；目标时间为 15 秒后，省电模式可能延后。是否收到请查看通知栏。'),
        findsOneWidget,
      );
      expect(find.text('1 条'), findsOneWidget);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
