class NotificationCenterLabels {
  static String time(int hour, int minute) =>
      '${hour.clamp(0, 23).toString().padLeft(2, '0')}:${minute.clamp(0, 59).toString().padLeft(2, '0')}';

  static String weekday(int value) {
    const labels = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final index = (value - 1).clamp(0, labels.length - 1);
    return labels[index];
  }

  static String monthDay(int value) => '每月 ${value.clamp(1, 28)} 日';
}
