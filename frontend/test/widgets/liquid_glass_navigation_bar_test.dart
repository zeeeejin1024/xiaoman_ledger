import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/navigation_motion_controller.dart';
import 'package:xiaojia_ledger/widgets/liquid_glass_navigation_bar.dart';

void main() {
  tearDown(() => AppColors.apply(AppColorScheme.warmAmber));

  test(
    'navigation indicator uses rounded glass shapes without dots or lines',
    () {
      final liquidPainter = File('lib/widgets/liquid_glass_trail_painter.dart');
      final oldPainter = File('lib/widgets/meteor_trail_painter.dart');

      expect(liquidPainter.existsSync(), isTrue);
      expect(oldPainter.existsSync(), isFalse);

      final source = liquidPainter.readAsStringSync();
      expect(source, contains('drawRRect'));
      expect(source, isNot(contains('drawCircle')));
      expect(source, isNot(contains('drawLine')));
      expect(source, isNot(contains('MaskFilter.blur')));
    },
  );

  testWidgets('navigation surface uses the active scheme navigation color', (
    tester,
  ) async {
    AppColors.apply(AppColorScheme.darkInk);
    final controller = NavigationMotionController(position: 0);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          bottomNavigationBar: LiquidGlassNavigationBar(
            selectedIndex: 0,
            onSelected: (_) {},
            controller: controller,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.insights), label: '统计'),
            ],
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('tab-gesture-surface')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((decorated.decoration as BoxDecoration).color, AppColors.navBg);
    controller.dispose();
  });

  testWidgets('dragging right selects the destination on the right', (
    tester,
  ) async {
    final controller = NavigationMotionController(position: 1);
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidGlassNavigationBar(
            selectedIndex: 1,
            onSelected: (index) => selected = index,
            controller: controller,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.insights), label: '统计'),
              NavigationDestination(icon: Icon(Icons.savings), label: '存钱'),
              NavigationDestination(icon: Icon(Icons.receipt), label: '流水'),
              NavigationDestination(icon: Icon(Icons.person), label: '我的'),
            ],
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('tab-gesture-surface')),
      const Offset(180, 0),
    );
    await tester.pump();

    expect(selected, 2);
    controller.dispose();
  });

  testWidgets('dragging left selects the destination on the left', (
    tester,
  ) async {
    final controller = NavigationMotionController(position: 1);
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LiquidGlassNavigationBar(
            selectedIndex: 1,
            onSelected: (index) => selected = index,
            controller: controller,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: '首页'),
              NavigationDestination(icon: Icon(Icons.insights), label: '统计'),
              NavigationDestination(icon: Icon(Icons.savings), label: '存钱'),
              NavigationDestination(icon: Icon(Icons.receipt), label: '流水'),
              NavigationDestination(icon: Icon(Icons.person), label: '我的'),
            ],
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('tab-gesture-surface')),
      const Offset(-180, 0),
    );
    await tester.pump();

    expect(selected, 0);
    controller.dispose();
  });
}
