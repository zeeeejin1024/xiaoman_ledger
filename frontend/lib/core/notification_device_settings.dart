import 'package:flutter/services.dart';

class NotificationDeviceGuide {
  final String brandName;
  final List<String> steps;
  final String fallback;
  const NotificationDeviceGuide(this.brandName, this.steps, this.fallback);

  factory NotificationDeviceGuide.fromManufacturer(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('xiaomi') || value.contains('redmi'))
      return const NotificationDeviceGuide('小米 / Redmi', [
        '允许通知权限',
        '在自启动管理中允许小满记账',
        '省电策略选择“无限制”',
      ], '若无法跳转，请在系统设置中搜索“小满记账”。');
    if (value.contains('huawei'))
      return const NotificationDeviceGuide('华为', [
        '允许通知权限',
        '进入应用启动管理',
        '关闭自动管理并允许后台活动',
      ], '若页面不同，请在手机管家中搜索“应用启动管理”。');
    if (value.contains('honor'))
      return const NotificationDeviceGuide('荣耀', [
        '允许通知权限',
        '进入应用启动管理',
        '允许自启动和后台运行',
      ], '若页面不同，请在系统设置中搜索“应用启动管理”。');
    if (value.contains('oppo') || value.contains('realme'))
      return const NotificationDeviceGuide('OPPO / realme', [
        '允许通知权限',
        '允许自启动',
        '允许后台运行并关闭过度省电',
      ], '若无法跳转，请在电池设置中找到小满记账。');
    if (value.contains('vivo') || value.contains('iqoo'))
      return const NotificationDeviceGuide('vivo / iQOO', [
        '允许通知权限',
        '在后台耗电管理中允许运行',
        '开启自启动',
      ], '若无法跳转，请在权限管理中搜索小满记账。');
    if (value.contains('samsung'))
      return const NotificationDeviceGuide('三星', [
        '允许通知权限',
        '从休眠应用中移除小满记账',
        '允许后台使用电量',
      ], '若无法跳转，请进入电池与设备维护。');
    return const NotificationDeviceGuide('Android', [
      '允许通知权限',
      '允许后台活动',
      '不要将小满记账加入休眠应用',
    ], '系统页面因品牌而异，可在应用详情页完成设置。');
  }
}

class NotificationDeviceSettings {
  static const _channel = MethodChannel('xiaojia/notification_settings');
  static Future<String> manufacturer() async =>
      await _channel.invokeMethod<String>('getManufacturer') ?? 'Android';
  static Future<void> openNotificationSettings() =>
      _channel.invokeMethod('openNotificationSettings');
  static Future<void> openBackgroundSettings() =>
      _channel.invokeMethod('openBackgroundSettings');
  static Future<void> openBatterySettings() =>
      _channel.invokeMethod('openBatterySettings');
}
