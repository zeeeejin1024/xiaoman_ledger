import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:xiaojia_ledger/core/constants.dart';

void main() {
  test('app version is bumped for savings history and layout fixes', () {
    expect(AppConstants.appVersion, '7.0.10');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 7.0.10+37'));
  });
}
