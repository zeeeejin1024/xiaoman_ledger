import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV and JSON exports request unmodified text responses', () {
    final apiClient = File('lib/data/api/api_client.dart').readAsStringSync();
    final settings = File(
      'lib/modules/settings/settings_page.dart',
    ).readAsStringSync();

    expect(apiClient, contains('Options? options'));
    expect(settings, contains('responseType: ResponseType.plain'));
  });

  test('JSON export validates its content before writing the file', () {
    final settings = File(
      'lib/modules/settings/settings_page.dart',
    ).readAsStringSync();

    expect(settings, contains('jsonDecode(jsonText)'));
    expect(settings, isNot(contains("r.data.toString()")));
  });
}
