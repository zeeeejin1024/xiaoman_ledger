import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/notification_preferences.dart';
import 'package:xiaojia_ledger/core/notification_coordinator.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/api/record_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Interceptor stub;
  var success = true;
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'notification_rules_v2_migrated': true,
      'notification.weekly_enabled': false,
      'notification.monthly_enabled': false,
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'pendingNotificationRequests') return [];
          return null;
        });
    FlutterSecureStorage.setMockInitialValues({});
    success = true;
    stub = InterceptorsWrapper(
      onRequest: (request, handler) {
        handler.resolve(
          Response(
            requestOptions: request,
            statusCode: 200,
            data: {
              'code': success ? 0 : 1,
              'message': success ? 'ok' : 'rejected',
              'data': success
                  ? {'id': 1, ...request.data as Map<String, dynamic>}
                  : null,
            },
          ),
        );
      },
    );
    ApiClient().dio.interceptors.add(stub);
  });
  tearDown(() async {
    await (await NotificationCoordinator.shared()).reconcileAll();
    ApiClient().dio.interceptors.remove(stub);
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('any successful record path persists today suppression', () async {
    final now = DateTime.now();
    final result = await RecordApi.addRecord(
      type: 'expense',
      amount: 10,
      categoryId: 1,
      date: now.toIso8601String().split('T').first,
    );
    expect(result.isSuccess, isTrue);
    expect(
      (await NotificationPreferencesRepository.create()).hasRecordedOn(now),
      isTrue,
    );
  });

  test('failed and historical saves do not suppress today reminders', () async {
    final now = DateTime.now();
    success = false;
    await RecordApi.addRecord(
      type: 'expense',
      amount: 10,
      categoryId: 1,
      date: now.toIso8601String().split('T').first,
    );
    success = true;
    await RecordApi.addRecord(
      type: 'expense',
      amount: 10,
      categoryId: 1,
      date: now
          .subtract(const Duration(days: 2))
          .toIso8601String()
          .split('T')
          .first,
    );
    expect(
      (await NotificationPreferencesRepository.create()).hasRecordedOn(now),
      isFalse,
    );
  });
}
