import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/theme.dart';

void main() {
  testWidgets('shared cards avoid per-instance backdrop blur layers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PremiumCard(child: Text('账单摘要'))),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(PremiumCard),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PremiumCard),
        matching: find.byType(ClipRRect),
      ),
      findsOneWidget,
    );
    expect(find.text('账单摘要'), findsOneWidget);
  });
}
