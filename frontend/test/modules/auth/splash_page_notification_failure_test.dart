import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/constants.dart';
import 'package:xiaojia_ledger/modules/auth/splash_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('通知初始化失败也会继续进入首页', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'existing-token',
    });
    SharedPreferences.setMockInitialValues({
      'last_auth_check': DateTime.now().toIso8601String(),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          prepareNotifications: () async => throw StateError('notification'),
        ),
        routes: {'/home': (_) => const Scaffold(body: Text('首页已打开'))},
      ),
    );

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();

    expect(find.text('首页已打开'), findsOneWidget);
  });

  testWidgets('通知初始化缓慢不会阻塞进入首页', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'existing-token',
    });
    SharedPreferences.setMockInitialValues({
      'last_auth_check': DateTime.now().toIso8601String(),
    });
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(prepareNotifications: () => pending.future),
        routes: {'/home': (_) => const Scaffold(body: Text('首页已打开'))},
      ),
    );
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpAndSettle();
    expect(find.text('首页已打开'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
  });
}
