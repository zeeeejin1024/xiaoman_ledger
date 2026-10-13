import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/theme.dart';

void main() {
  tearDown(() => AppColors.apply(AppColorScheme.warmAmber));

  test('warmAmber uses the approved graphite blue and rose berry palette', () {
    AppColors.apply(AppColorScheme.warmAmber);

    expect(AppColors.bg, const Color(0xFFF4F4F0));
    expect(AppColors.accent, const Color(0xFF273640));
    expect(AppColors.info, const Color(0xFF587A86));
    expect(AppColors.danger, const Color(0xFFB45B6C));
    expect(AppColors.highlight, const Color(0xFFB45B6C));
    expect(AppColors.premiumLight, const Color(0xFF8FA8AF));
    expect(AppColors.coral, const Color(0xFFB45B6C));
  });

  test('apply notifies listeners so Material themes can rebuild', () {
    var notifications = 0;
    void listener() => notifications++;
    AppColors.notifier.addListener(listener);

    AppColors.apply(AppColorScheme.mistBlue);

    expect(AppColors.notifier.value, AppColorScheme.mistBlue);
    expect(notifications, 1);
    expect(appTheme().navigationBarTheme.backgroundColor, AppColors.navBg);
    expect(
      appTheme().bottomNavigationBarTheme.backgroundColor,
      AppColors.navBg,
    );
    expect(
      appTheme().navigationBarTheme.labelTextStyle!.resolve({
        WidgetState.selected,
      })!.color,
      AppColors.info,
    );

    AppColors.notifier.removeListener(listener);
  });

  testWidgets(
    'theme builder refreshes cached content when the scheme changes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppThemeBuilder(builder: (_, scheme) => Text(scheme.name)),
        ),
      );
      expect(find.text('未满之圆'), findsOneWidget);

      AppColors.apply(AppColorScheme.deepNight);
      await tester.pump();

      expect(find.text('极夜'), findsOneWidget);
    },
  );
}
