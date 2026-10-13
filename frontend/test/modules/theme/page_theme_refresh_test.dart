import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/theme.dart';

class StatefulThemeProbe extends StatefulWidget {
  const StatefulThemeProbe({super.key});

  @override
  State<StatefulThemeProbe> createState() => _StatefulThemeProbeState();
}

class _StatefulThemeProbeState extends State<StatefulThemeProbe> {
  var count = 0;

  @override
  Widget build(BuildContext context) {
    return AppThemedPage(
      builder: (context, scheme) => ColoredBox(
        key: const ValueKey('page-color'),
        color: AppColors.bg,
        child: TextButton(
          onPressed: () => setState(() => count++),
          child: Text('${scheme.name}:$count'),
        ),
      ),
    );
  }
}

void main() {
  tearDown(() => AppColors.apply(AppColorScheme.warmAmber));

  testWidgets('page theme refresh preserves state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StatefulThemeProbe()));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(find.text('未满之圆:1'), findsOneWidget);

    AppColors.apply(AppColorScheme.deepNight);
    await tester.pump();

    expect(find.text('极夜:1'), findsOneWidget);
    expect(
      tester.widget<ColoredBox>(find.byKey(const ValueKey('page-color'))).color,
      AppColorScheme.deepNight.bg,
    );
  });

  test('every primary page subscribes to theme changes', () {
    const pagePaths = [
      'lib/modules/stats/stats_page.dart',
      'lib/modules/savings/savings_page.dart',
      'lib/modules/record/records_list_page.dart',
      'lib/modules/profile/profile_page.dart',
      'lib/modules/wallet/wallet_page.dart',
      'lib/modules/report/weekly_report_page.dart',
      'lib/modules/report/monthly_report_page.dart',
      'lib/modules/settings/settings_page.dart',
      'lib/modules/voice/voice_page.dart',
    ];

    for (final path in pagePaths) {
      expect(
        File(path).readAsStringSync(),
        contains('AppThemedPage('),
        reason: path,
      );
    }
  });
}
