import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android build does not request unused calendar permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, isNot(contains('android.permission.READ_CALENDAR')));
    expect(manifest, isNot(contains('android.permission.WRITE_CALENDAR')));
  });

  test('settings do not expose the placeholder calendar switch', () {
    final settings = File(
      'lib/modules/settings/settings_page.dart',
    ).readAsStringSync();

    expect(settings, isNot(contains('CalendarService')));
    expect(settings, isNot(contains("'日历同步'")));
  });
}
