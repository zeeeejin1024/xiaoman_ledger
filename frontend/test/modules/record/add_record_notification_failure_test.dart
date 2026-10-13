import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/data/api/api_client.dart';
import 'package:xiaojia_ledger/modules/record/add_record_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late Interceptor api;
  var saves = 0;
  var savedCallbacks = 0;
  var failRecord = false;

  setUp(() {
    saves = 0;
    savedCallbacks = 0;
    failRecord = false;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return true;
          if (call.method == 'cancel' || call.method == 'zonedSchedule') {
            throw PlatformException(code: 'notifications_unavailable');
          }
          if (call.method == 'pendingNotificationRequests') return [];
          return null;
        });
    api = InterceptorsWrapper(
      onRequest: (request, handler) {
        if (request.path == '/categories') {
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'code': 0,
                'data': [
                  {'id': 1, 'name': '餐饮', 'type': 'expense'},
                ],
              },
            ),
          );
          return;
        }
        if (request.path == '/records' && request.method == 'POST') {
          saves++;
          if (failRecord) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
              ),
            );
            return;
          }
          handler.resolve(
            Response(
              requestOptions: request,
              data: {
                'code': 0,
                'data': {'id': 1, ...request.data as Map<String, dynamic>},
              },
            ),
          );
          return;
        }
        throw StateError('Unexpected endpoint ${request.path}');
      },
    );
    ApiClient().dio.interceptors.add(api);
  });
  tearDown(() {
    ApiClient().dio.interceptors.remove(api);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(450, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AddRecordSheet(onSaved: () => savedCallbacks++),
              ),
              child: const Text('打开记账'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开记账'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '0.00',
      ),
      '12',
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'notification failure does not keep a successfully saved sheet open',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('保 存'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AddRecordSheet), findsNothing);
      expect(savedCallbacks, 1);
      expect(saves, 1);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'record network failure restores save button and permits retry',
    (tester) async {
      failRecord = true;
      await open(tester);
      await tester.tap(find.text('保 存'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('保存失败，请检查网络后重试'), findsOneWidget);
      expect(find.text('保 存'), findsOneWidget);
      failRecord = false;
      await tester.tap(find.text('保 存'));
      await tester.pumpAndSettle();
      expect(find.byType(AddRecordSheet), findsNothing);
      expect(saves, 2);
      expect(savedCallbacks, 1);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
