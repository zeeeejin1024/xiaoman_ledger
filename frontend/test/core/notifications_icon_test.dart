import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/core/notifications.dart';

void main() {
  test('Android notifications use the dedicated monochrome brand icon', () {
    expect(NotificationService.androidSmallIcon, 'ic_notification');

    final resource = File(
      'android/app/src/main/res/drawable/ic_notification.xml',
    );
    expect(resource.existsSync(), isTrue);
    expect(resource.readAsStringSync(), contains('<vector'));
  });

  test('Android release shrinking preserves the notification icon', () {
    final keepRules = File('android/app/src/main/res/raw/keep.xml');

    expect(keepRules.existsSync(), isTrue);
    expect(
      keepRules.readAsStringSync(),
      contains('tools:keep="@drawable/ic_notification"'),
    );
  });
}
