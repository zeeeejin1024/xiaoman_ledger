import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaojia_ledger/modules/profile/profile_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('profile editing controls expose large hit targets', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pump();

    final editTarget = find.byKey(const ValueKey('profile-edit-hit-target'));
    expect(tester.getSize(editTarget).height, greaterThanOrEqualTo(96));

    final arrow = find.descendant(
      of: editTarget,
      matching: find.byIcon(Icons.chevron_right),
    );
    expect(tester.widget<Icon>(arrow).size, 22);

    await tester.tap(editTarget);
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(find.byKey(const ValueKey('profile-save-hit-target')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });
}
