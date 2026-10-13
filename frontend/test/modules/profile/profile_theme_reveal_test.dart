import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/core/theme_reveal.dart';
import 'package:xiaojia_ledger/modules/profile/profile_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.apply(AppColorScheme.mistBlue);
  });
  tearDown(() => AppColors.apply(AppColorScheme.warmAmber));
  test(
    'application mounts reveal over system UI with no competing theme tween',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      expect(source, contains('themeAnimationDuration: Duration.zero'));
      expect(source, contains('ThemeReveal('));
      expect(source, contains('themeRevealNavigationObserver'));
      expect(
        File('lib/modules/home/home_page.dart').readAsStringSync(),
        contains('ThemeReveal.finish(context)'),
      );
    },
  );
  testWidgets(
    'label uses its swatch center and global selection stays current',
    (tester) async {
      var captures = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ThemeReveal(
            capture: (_, _) async {
              captures++;
              throw StateError('capture fallback');
            },
            child: const ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choice = find.byKey(const ValueKey('theme-choice-5'));
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppColorScheme.deepNight.name));
      await tester.pumpAndSettle();
      expect(captures, 1);
      expect(AppColors.scheme, AppColorScheme.deepNight);
      expect((await SharedPreferences.getInstance()).getInt('color_scheme'), 5);
      final selected = tester.widget<Semantics>(
        find.byKey(const ValueKey('theme-semantics-5')),
      );
      expect(selected.properties.selected, isTrue);
      AppColors.apply(AppColorScheme.roseGold);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('theme-semantics-3')))
            .properties
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('theme-semantics-5')))
            .properties
            .selected,
        isFalse,
      );
    },
  );
  testWidgets('save failure is shown inline without undoing chosen palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ThemeReveal(
            save: (_) async => false,
            child: const ProfilePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final choice = find.byKey(const ValueKey('theme-choice-5'));
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(AppColors.scheme, AppColorScheme.deepNight);
    expect(find.text('配色已切换，但保存失败，请重试'), findsOneWidget);
  });
  testWidgets(
    'signature label click reveals from swatch center after scrolling',
    (tester) async {
      final gate = Completer<ui.Image>();
      await tester.pumpWidget(
        MaterialApp(
          home: ThemeReveal(
            capture: (_, _) => gate.future,
            child: const ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choice = find.byKey(const ValueKey('theme-choice-5'));
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      final circle = find
          .descendant(of: choice, matching: find.byType(Container))
          .first;
      final center = tester.getCenter(circle);
      await tester.tap(find.text(AppColorScheme.deepNight.name));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      final captured = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(AppColorScheme.mistBlue.bg, BlendMode.src);
        final picture = recorder.endRecording();
        final img = await picture.toImage(800, 600);
        picture.dispose();
        return img;
      });
      gate.complete(captured!);
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      final mask = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('theme-reveal-mask')),
      );
      final origin = (mask.painter as dynamic).origin as Offset;
      expect(origin, center);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(captured.debugDisposed, isTrue);
    },
  );
}
