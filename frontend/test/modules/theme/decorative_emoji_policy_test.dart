import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decorative screens use app icons instead of emoji glyphs', () {
    const decorativeEmoji = <String>[
      '💰',
      '📊',
      '🎯',
      '🐣',
      '🌟',
      '😊',
      '😅',
      '😰',
      '🎉',
      '😢',
      '💪',
      '😴',
      '💼',
      '🏃',
      '🍜',
      '🎵',
      '📚',
      '✈️',
    ];
    const sources = <String>[
      'lib/modules/onboarding/onboarding_page.dart',
      'lib/modules/report/weekly_report_page.dart',
      'lib/modules/report/monthly_report_page.dart',
      'lib/modules/profile/profile_page.dart',
    ];

    for (final path in sources) {
      final source = File(path).readAsStringSync();
      for (final emoji in decorativeEmoji) {
        expect(
          source,
          isNot(contains(emoji)),
          reason: '$path should not use decorative emoji $emoji',
        );
      }
    }
  });
}
