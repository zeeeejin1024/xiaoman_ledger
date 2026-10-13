import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaojia_ledger/modules/notifications/notification_center_labels.dart';

void main() {
  test('formats notification times with two digits', () {
    expect(NotificationCenterLabels.time(7, 5), '07:05');
    expect(NotificationCenterLabels.time(21, 0), '21:00');
  });

  test('uses Chinese weekday labels for the scheduler values', () {
    expect(NotificationCenterLabels.weekday(1), '周一');
    expect(NotificationCenterLabels.weekday(7), '周日');
    expect(NotificationCenterLabels.weekday(0), '周一');
  });

  test('clamps monthly day labels to the supported 1 to 28 range', () {
    expect(NotificationCenterLabels.monthDay(0), '每月 1 日');
    expect(NotificationCenterLabels.monthDay(15), '每月 15 日');
    expect(NotificationCenterLabels.monthDay(31), '每月 28 日');
  });

  test('notification center exposes every configurable local rule', () {
    final source = File(
      'lib/modules/notifications/notification_center_page.dart',
    ).readAsStringSync();
    for (final key in const [
      'notification-rule-daily',
      'notification-rule-weekly',
      'notification-rule-monthly',
      'notification-rule-budget',
      'notification-rule-living',
      'notification-rule-deals',
    ]) {
      expect(source, contains(key));
    }
    expect(source, contains('showTimePicker'));
    expect(source, contains('showModalBottomSheet'));
  });
}
