import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';
import 'package:xiaojia_ledger/core/notification_policy.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final pending = <int>{};
  final shown = <Map>[];
  final scheduled = <Map>[];
  late NotificationCoordinator coordinator;
  late SharedPreferences prefs;
  late Interceptor api;
  bool failDaily = false;
  bool failShow = false;
  bool failWallets = false;
  int walletRequests = 0;
  const disabled = NotificationPreferences(
    dailyEnabled: false,
    budgetEnabled: false,
    livingEnabled: false,
    weeklyEnabled: false,
    monthlyEnabled: false,
    dealsEnabled: false,
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'notification_rules_v2_migrated': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    coordinator = await NotificationCoordinator.shared();
  });
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    pending.clear();
    shown.clear();
    scheduled.clear();
    failDaily = false;
    failShow = false;
    failWallets = false;
    walletRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'zonedSchedule') {
            final args = call.arguments as Map;
            final id = args['id'] as int;
            scheduled.add(args);
            if (failDaily && NotificationPolicy.dailyWindowIds.contains(id)) {
              throw PlatformException(code: 'daily_failed');
            }
            pending.add(id);
          }
          if (call.method == 'show') {
            if (failShow) throw PlatformException(code: 'show_failed');
            shown.add(call.arguments as Map);
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
    api = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path != '/wallets') {
          throw StateError('unexpected endpoint ${request.path}');
        }
        walletRequests++;
        if (failWallets) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {'code': 1, 'message': 'unavailable'},
            ),
          );
          return;
        }
        handler.resolve(
          Response(
            requestOptions: request,
            statusCode: 200,
            data: {
              'code': 0,
              'data': [
                {
                  'id': 17,
                  'name': '一日三餐',
                  'amount': 100,
                  'spent': 120,
                  'remaining': -20,
                  'bindings': [
                    {'category_id': 4, 'include_descendants': true},
                  ],
                },
              ],
            },
          ),
        );
      },
    );
    ApiClient().dio.interceptors.add(api);
    await prefs.clear();
    await coordinator.update(disabled);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    ApiClient().dio.interceptors.remove(api);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'daily failure does not stop independent weekly and monthly reminders',
    () async {
      failDaily = true;
      final ok = await coordinator.update(
        disabled.copyWith(
          dailyEnabled: true,
          weeklyEnabled: true,
          monthlyEnabled: true,
        ),
      );
      expect(ok, isFalse);
      expect(
        pending,
        containsAll([
          NotificationPolicy.weeklyReportId,
          NotificationPolicy.monthlyReportId,
        ]),
      );
    },
  );

  test(
    'server wallet totals drive alerts; a failed send can retry after reconciliation',
    () async {
      await prefs.setStringList('active_wallets', ['999']);
      await prefs.setDouble('wallet_budget_999', 1);
      failShow = true;
      await coordinator.update(disabled.copyWith(budgetEnabled: true));
      expect(coordinator.preferences.thresholdKeys(), isEmpty);
      failShow = false;
      await Future.wait([
        coordinator.evaluateBudgets(),
        coordinator.evaluateBudgets(),
      ]);
      expect(walletRequests, greaterThan(0));
      expect(shown, hasLength(1));
      expect(shown.single['id'], NotificationPolicy.budgetId('wallet:17:100%'));
      expect(shown.single['body'], contains('100%'));
      expect(
        coordinator.preferences.thresholdKeys().every(
          (key) => key.contains('|wallet:17|'),
        ),
        isTrue,
      );
    },
  );

  test(
    'record save and later refresh both preserve tomorrow as first reminder',
    () async {
      final today = DateTime.now();
      await coordinator.update(
        disabled.copyWith(dailyEnabled: true, dailyHour: 23, dailyMinute: 59),
      );
      await coordinator.onRecordSaved(date: today, type: 'expense');
      scheduled.clear();
      await coordinator.reconcileAll();
      final first = DateTime.parse(scheduled.first['scheduledDateTime']);
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      expect(DateTime(first.year, first.month, first.day), tomorrow);
      expect(pending, NotificationPolicy.dailyWindowIds.toSet());
    },
  );

  test(
    'unavailable wallet totals never fall back to obsolete category budgets',
    () async {
      await prefs.setStringList('active_wallets', ['999']);
      await prefs.setDouble('wallet_budget_999', 1);
      failWallets = true;
      await coordinator.update(disabled.copyWith(budgetEnabled: true));
      await expectLater(coordinator.evaluateBudgets(), completes);
      expect(shown, isEmpty);
      expect(coordinator.preferences.thresholdKeys(), isEmpty);
      failWallets = false;
      await coordinator.evaluateBudgets();
      expect(shown, hasLength(1));
    },
  );
}
