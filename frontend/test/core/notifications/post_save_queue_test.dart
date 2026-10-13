import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/notification_policy.dart';
import 'package:xiaojia_ledger/core/notifications.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/data/api/record_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'successful common save renews daily queue even if subsequent data load fails',
    () async {
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      SharedPreferences.setMockInitialValues({
        'notification_rules_v2_migrated': true,
        'notification.daily_enabled': true,
        'notification.daily_hour': 23,
        'notification.daily_minute': 59,
        'notification.weekly_enabled': false,
        'notification.monthly_enabled': false,
      });
      FlutterSecureStorage.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final registered = <int, String>{};
      final refreshed = Completer<void>();
      var saving = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'zonedSchedule') {
              final args = call.arguments as Map;
              registered[args['id'] as int] =
                  args['scheduledDateTime'] as String;
            }
            if (call.method == 'cancel') {
              registered.remove((call.arguments as Map)['id']);
            }
            if (call.method == 'pendingNotificationRequests') {
              if (saving && registered.length == 30 && !refreshed.isCompleted) {
                refreshed.complete();
              }
              return registered.keys
                  .map(
                    (id) => {'id': id, 'title': '', 'body': '', 'payload': ''},
                  )
                  .toList();
            }
            return null;
          });
      final api = InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.method == 'GET') {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'code': 0,
                  'data': {'id': 1, ...request.data as Map<String, dynamic>},
                },
              ),
            );
          }
        },
      );
      ApiClient().dio.interceptors.add(api);
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        ApiClient().dio.interceptors.remove(api);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await NotificationService.scheduleDailyReminder(hour: 23, minute: 59);
      final now = DateTime.now();
      saving = true;
      final result = await RecordApi.addRecord(
        type: 'expense',
        amount: 12,
        categoryId: 1,
        date: now.toIso8601String().split('T').first,
      );
      expect(result.isSuccess, isTrue);
      await expectLater(RecordApi.getRecords(), throwsA(isA<DioException>()));
      await refreshed.future.timeout(const Duration(seconds: 2));
      final first = DateTime.parse(
        registered[NotificationPolicy.dailyReminderId]!,
      );
      expect(
        DateTime(first.year, first.month, first.day),
        DateTime(now.year, now.month, now.day + 1),
      );
    },
  );
}
