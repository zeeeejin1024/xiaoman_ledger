import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/notification_models.dart';
import 'package:xiaojia_ledger/core/notifications/schedule_plan.dart';
import 'package:xiaojia_ledger/modules/notifications/notification_center_backend.dart';
import 'package:xiaojia_ledger/modules/notifications/notification_center_page.dart';

class FakeBackend implements NotificationCenterBackend {
  bool failLoad = false;
  bool failSave = false;
  bool allowed = false;
  int reconciles = 0;
  int saves = 0;
  Completer<void>? saving;
  NotificationPreferences settings = const NotificationPreferences();

  @override
  Future<NotificationCenterSnapshot> load({bool reconcile = true}) async {
    if (failLoad) throw StateError('unavailable');
    if (reconcile) reconciles++;
    return NotificationCenterSnapshot(
      settings: settings,
      permission: allowed,
      dailyState: AuditState.disabled,
      pendingIds: const {},
    );
  }

  @override
  Future<bool> save(NotificationPreferences next) async {
    saves++;
    if (failSave) throw StateError('storage unavailable');
    if (saving != null) await saving!.future;
    settings = next;
    return true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> open(WidgetTester tester, FakeBackend backend) async {
    await tester.pumpWidget(
      MaterialApp(home: NotificationCenterPage(backend: backend)),
    );
    await tester.pumpAndSettle();
  }

  Finder dailySwitch() => find.descendant(
    of: find.byKey(const ValueKey('notification-rule-daily')),
    matching: find.byType(SwitchListTile),
  );

  testWidgets('initial failure offers retry rather than endless loading', (
    tester,
  ) async {
    final backend = FakeBackend()..failLoad = true;
    await open(tester, backend);
    expect(find.text('通知设置读取失败，请重试'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    backend.failLoad = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(dailySwitch(), findsOneWidget);
  });

  testWidgets('resume reloads permission changed in system settings', (
    tester,
  ) async {
    final backend = FakeBackend();
    await open(tester, backend);
    expect(find.text('系统通知权限未开启'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    backend.allowed = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('系统通知权限已开启'), findsOneWidget);
    expect(backend.reconciles, 2);
  });

  testWidgets('saving locks controls and does not reconcile twice', (
    tester,
  ) async {
    final backend = FakeBackend()..allowed = true;
    await open(tester, backend);
    backend.saving = Completer<void>();
    await tester.tap(dailySwitch());
    await tester.pump();
    expect(tester.widget<SwitchListTile>(dailySwitch()).onChanged, isNull);
    backend.saving!.complete();
    await tester.pumpAndSettle();
    expect(backend.saves, 1);
    expect(backend.reconciles, 1);
    expect(tester.widget<SwitchListTile>(dailySwitch()).value, isTrue);
  });

  testWidgets('failed save restores controls with an accurate error', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..allowed = true
      ..failSave = true;
    await open(tester, backend);
    await tester.tap(dailySwitch());
    await tester.pumpAndSettle();
    expect(find.text('设置保存失败，请重试'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(dailySwitch()).onChanged, isNotNull);
    expect(tester.widget<SwitchListTile>(dailySwitch()).value, isFalse);
    backend.failSave = false;
    await tester.tap(dailySwitch());
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(dailySwitch()).value, isTrue);
  });

  testWidgets('enabled report without pending ID is not claimed scheduled', (
    tester,
  ) async {
    await open(tester, FakeBackend()..allowed = true);
    expect(find.text('系统队列未确认，请下拉重试'), findsWidgets);
    expect(find.text('每周自动生成并提醒'), findsNothing);
  });

  testWidgets('notification controls fit a narrow screen with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: NotificationCenterPage(backend: FakeBackend()..allowed = true),
      ),
    );
    await tester.pumpAndSettle();
    for (final id in ['weekly', 'monthly', 'living', 'deals']) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('notification-rule-$id')),
        220,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
