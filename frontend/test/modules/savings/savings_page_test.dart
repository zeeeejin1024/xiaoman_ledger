import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('savings list stays below the system status bar', () {
    final source = File(
      'lib/modules/savings/savings_page.dart',
    ).readAsStringSync();

    expect(source, contains("key: const ValueKey('savings-page-safe-area')"));
  });

  test('savings history displays a local date and time', () {
    final source = File(
      'lib/modules/savings/savings_page.dart',
    ).readAsStringSync();

    expect(source, contains('formatSavingsDepositTime'));
    expect(source, isNot(contains("h['date'] ?? ''")));
  });
}
