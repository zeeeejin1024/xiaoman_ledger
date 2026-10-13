import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/theme.dart';
import 'package:xiaojia_ledger/main.dart';

void main() {
  test(
    'native bridge supports independent status and navigation icon modes',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('xiaojia/system_ui'), (
            call,
          ) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('xiaojia/system_ui'),
              null,
            ),
      );
      await AppSystemUiBridge.apply(
        AppColorScheme.deepNight,
        overlay: AppColors.overlayForScheme(
          AppColorScheme.mistBlue,
        ).copyWith(systemNavigationBarIconBrightness: Brightness.light),
      );
      expect(calls.single.arguments, {
        'isDark': false,
        'navigationIsDark': true,
      });
    },
  );
  testWidgets(
    'root follows temporary icon override then restores target style',
    (tester) async {
      await tester.pumpWidget(
        const AppSystemUi(
          scheme: AppColorScheme.deepNight,
          child: SizedBox.expand(),
        ),
      );
      AppColors.systemUiOverride.value = AppColors.overlayForScheme(
        AppColorScheme.mistBlue,
      );
      await tester.pump();
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byKey(const ValueKey('app-system-ui-region')),
      );
      expect(region.value.statusBarIconBrightness, Brightness.dark);
      AppColors.apply(AppColorScheme.deepNight);
      AppColors.systemUiOverride.value = null;
      await tester.pump();
      expect(
        tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byKey(const ValueKey('app-system-ui-region')),
            )
            .value
            .statusBarIconBrightness,
        Brightness.light,
      );
    },
  );
  tearDown(() => AppColors.apply(AppColorScheme.warmAmber));

  test('system bars and app navigation resolve from the active scheme', () {
    AppColors.apply(AppColorScheme.deepNight);

    final overlay = AppColors.systemUiOverlayStyle;
    final theme = appTheme();

    expect(overlay.systemNavigationBarColor, AppColorScheme.deepNight.navBg);
    expect(overlay.systemNavigationBarIconBrightness, Brightness.light);
    expect(overlay.systemStatusBarContrastEnforced, isFalse);
    expect(overlay.systemNavigationBarContrastEnforced, isFalse);
    expect(
      theme.navigationBarTheme.backgroundColor,
      AppColorScheme.deepNight.navBg,
    );
    expect(theme.appBarTheme.systemOverlayStyle, overlay);
  });

  testWidgets('root system UI region updates in the same theme frame', (
    tester,
  ) async {
    AppColors.apply(AppColorScheme.mistBlue);
    await tester.pumpWidget(
      ValueListenableBuilder<AppColorScheme>(
        valueListenable: AppColors.notifier,
        builder: (_, scheme, _) =>
            AppSystemUi(child: SizedBox(key: ValueKey(scheme.name))),
      ),
    );

    AppColors.apply(AppColorScheme.deepNight);
    await tester.pump();

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('app-system-ui-region')),
    );
    expect(
      region.value.systemNavigationBarColor,
      AppColorScheme.deepNight.navBg,
    );
    expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
  });

  testWidgets(
    'root system UI layer paints the active scheme behind edge-to-edge bars',
    (tester) async {
      AppColors.apply(AppColorScheme.mistBlue);
      await tester.pumpWidget(
        ValueListenableBuilder<AppColorScheme>(
          valueListenable: AppColors.notifier,
          builder: (_, scheme, _) =>
              AppSystemUi(child: const SizedBox.expand()),
        ),
      );

      final background = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('app-system-ui-background')),
      );
      expect(background.color, AppColorScheme.mistBlue.bg);

      AppColors.apply(AppColorScheme.deepNight);
      await tester.pump();
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('app-system-ui-background')),
            )
            .color,
        AppColorScheme.deepNight.bg,
      );
    },
  );

  testWidgets('bottom system inset paints the active navigation color', (
    tester,
  ) async {
    AppColors.apply(AppColorScheme.darkInk);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(viewPadding: EdgeInsets.only(bottom: 24)),
        child: AppSystemUi(
          scheme: AppColorScheme.darkInk,
          child: SizedBox.expand(),
        ),
      ),
    );

    final background = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('app-system-navigation-background')),
    );
    expect(background.color, AppColorScheme.darkInk.navBg);
  });

  testWidgets(
    'root coordinator reapplies the active system style after a theme frame',
    (tester) async {
      final nativeCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('xiaojia/system_ui'), (
            call,
          ) async {
            nativeCalls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('xiaojia/system_ui'),
              null,
            );
      });

      AppColors.apply(AppColorScheme.deepNight);
      await tester.pumpWidget(
        const AppSystemUi(
          scheme: AppColorScheme.deepNight,
          child: SizedBox.expand(),
        ),
      );
      await tester.pump();

      expect(
        nativeCalls,
        contains(
          isA<MethodCall>()
              .having((call) => call.method, 'method', 'apply')
              .having((call) => call.arguments, 'arguments', <String, dynamic>{
                'isDark': true,
              }),
        ),
      );
    },
  );
}
