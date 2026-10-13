import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/modules/onboarding/onboarding_page.dart';

void main() {
  testWidgets('explains notification use before requesting permission', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var requested = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          onComplete: (_) {},
          requestNotificationPermission: () async {
            requested++;
            return true;
          },
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(find.text('让提醒按时出现'), findsOneWidget);
    expect(requested, 0);
    await tester.tap(find.text('开启通知'));
    await tester.pumpAndSettle();
    expect(requested, 1);
  });
}
